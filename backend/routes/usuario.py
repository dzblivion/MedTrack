import hashlib
import hmac
import logging
import os
import secrets
import time
from contextlib import contextmanager
from threading import Thread

import bcrypt
import jwt
from config.database import banco
from config.mail import mail
from flask import Blueprint, current_app, jsonify, request
from flask_mail import Message

usuario = Blueprint("usuario", __name__)
logger = logging.getLogger(__name__)

TEMPO_EXPIRACAO_CODIGO = 10 * 60
LIMITE_TENTATIVAS_CODIGO = 5


@contextmanager
def sessao_banco():
    """Abre uma transação e garante rollback e fechamento dos recursos."""
    conexao = None
    cursor = None

    try:
        conexao = banco()
        cursor = conexao.cursor()
        yield conexao, cursor
        conexao.commit()
    except Exception:
        if conexao is not None:
            try:
                conexao.rollback()
            except Exception:
                # Não esconda o erro original se a conexão já tiver caído.
                logger.exception("Não foi possível desfazer a transação")
        raise
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                logger.exception("Não foi possível fechar o cursor")
        if conexao is not None:
            try:
                conexao.close()
            except Exception:
                logger.exception("Não foi possível fechar a conexão")


def dados_json():
    """Evita AttributeError e respostas HTML para corpo ausente ou inválido."""
    dados = request.get_json(silent=True)
    return dados if isinstance(dados, dict) else {}


def texto_obrigatorio(dados, campo):
    valor = dados.get(campo)
    return valor.strip() if isinstance(valor, str) else ""


def email_valido(email):
    return isinstance(email, str) and "@" in email


def erro_chave_duplicada(erro):
    """Reconhece o erro 1062 do MySQL sem acoplar a um driver específico."""
    if getattr(erro, "errno", None) == 1062:
        return True

    argumentos = getattr(erro, "args", ())
    if argumentos and str(argumentos[0]) == "1062":
        return True

    return "duplicate entry" in str(erro).lower()


def segredo_codigo_recuperacao():
    # Em produção, prefira uma chave própria: RECUPERACAO_CODIGO_SECRET.
    segredo = os.getenv("RECUPERACAO_CODIGO_SECRET") or os.getenv("JWT_SECRET")
    if not segredo:
        raise RuntimeError("RECUPERACAO_CODIGO_SECRET ou JWT_SECRET não configurado")
    return segredo


def hash_codigo_recuperacao(codigo):
    """Não armazena o código de seis dígitos em texto puro no banco."""
    mensagem = f"recuperacao-senha:{codigo}".encode()
    return hmac.new(
        segredo_codigo_recuperacao().encode("utf-8"),
        mensagem,
        hashlib.sha256,
    ).hexdigest()


def codigo_recebido_valido(codigo):
    codigo = str(codigo).strip() if codigo is not None else ""
    return codigo if len(codigo) == 6 and codigo.isdigit() else None


def codigo_confere(codigo, codigo_hash):
    return hmac.compare_digest(
        hash_codigo_recuperacao(codigo), str(codigo_hash)
    )


def registrar_tentativa_invalida(cursor, recuperacao):
    tentativas = int(recuperacao["tentativas"]) + 1
    bloqueado = tentativas >= LIMITE_TENTATIVAS_CODIGO

    cursor.execute(
        """
        UPDATE recuperacoes_senha
        SET tentativas = %s,
            bloqueado_em = CASE WHEN %s THEN NOW() ELSE bloqueado_em END
        WHERE id = %s
        """,
        (tentativas, bloqueado, recuperacao["id"]),
    )

    return bloqueado


def buscar_recuperacao(cursor, email):
    # FOR UPDATE torna a contagem de tentativas segura contra requisições paralelas.
    cursor.execute(
        """
        SELECT
            r.id,
            r.codigo,
            r.expira_em,
            r.verificado,
            r.tentativas
        FROM recuperacoes_senha r
        INNER JOIN usuarios u ON r.usuario_id = u.id
        WHERE u.email = %s
        ORDER BY r.id DESC
        LIMIT 1
        FOR UPDATE
        """,
        (email,),
    )
    return cursor.fetchone()


def resposta_recuperacao_indisponivel():
    return jsonify({"erro": "Não foi possível processar a recuperação de senha!"}), 500


def criar_mensagem_recuperacao(email, codigo):
    mensagem = Message(
        subject="Código para redefinir sua senha - MedTrack",
        sender=os.getenv("MAIL_DEFAULT_SENDER", "dsgncece@gmail.com"),
        recipients=[email],
    )
    mensagem.body = (
        f"Seu código para redefinir a senha é: {codigo}.\n\n"
        "Ele é válido por 10 minutos."
    )
    return mensagem


def invalidar_recuperacao(recuperacao_id):
    """Executado se o SMTP falhar, em uma nova conexão ainda válida."""
    with sessao_banco() as (_, cursor):
        cursor.execute(
            "DELETE FROM recuperacoes_senha WHERE id = %s AND verificado = 0",
            (recuperacao_id,),
        )


def enviar_codigo_em_segundo_plano(app, email, codigo, recuperacao_id):
    """Uma fila de tarefas é preferível em produção; esta thread é um paliativo."""
    with app.app_context():
        try:
            mail.send(criar_mensagem_recuperacao(email, codigo))
        except Exception:
            logger.exception("Falha ao enviar e-mail de recuperação")
            try:
                invalidar_recuperacao(recuperacao_id)
            except Exception:
                logger.exception("Falha ao invalidar código cujo envio falhou")


def agendar_envio_codigo(email, codigo, recuperacao_id):
    app = current_app._get_current_object()
    Thread(
        target=enviar_codigo_em_segundo_plano,
        args=(app, email, codigo, recuperacao_id),
        daemon=True,
        name="envio-codigo-recuperacao",
    ).start()


def obter_usuario_id():
    cabecalho = request.headers.get("Authorization", "")
    if not cabecalho.startswith("Bearer "):
        return None

    token = cabecalho[7:]
    try:
        dados_token = jwt.decode(
            token,
            os.getenv("JWT_SECRET"),
            algorithms=["HS256"],
        )
        return dados_token["usuario_id"]
    except (jwt.InvalidTokenError, KeyError, TypeError):
        return None


@usuario.route("/cadastrar-usuario", methods=["POST"])
def cadastrar_usuario():
    dados = dados_json()
    nome = texto_obrigatorio(dados, "nome")
    email = texto_obrigatorio(dados, "email").lower()
    senha = dados.get("senha")

    if not nome:
        return jsonify({"erro": "Nome é obrigatório!"}), 400
    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400
    if not email_valido(email):
        return jsonify({"erro": "E-mail deve conter @."}), 400
    if not isinstance(senha, str) or not senha:
        return jsonify({"erro": "Senha é obrigatória!"}), 400
    if len(senha) < 8:
        return jsonify({"erro": "Senha deve ter pelo menos 8 caracteres!"}), 400

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                "INSERT INTO usuarios (nome, email, senha_hash) VALUES (%s, %s, %s)",
                (nome, email, senha_hash),
            )
    except Exception as erro:
        if erro_chave_duplicada(erro):
            return jsonify({"erro": "E-mail já cadastrado!"}), 409
        logger.exception("Erro ao cadastrar usuário")
        return jsonify({"erro": "Não foi possível cadastrar o usuário!"}), 500

    return jsonify({"mensagem": "Usuário cadastrado com sucesso!"}), 201


@usuario.route("/cadastrar-profissional", methods=["POST"])
def cadastrar_profissional():
    dados = dados_json()
    nome = texto_obrigatorio(dados, "nome")
    email = texto_obrigatorio(dados, "email").lower()
    senha = dados.get("senha")
    profissao = texto_obrigatorio(dados, "profissao")
    registro = texto_obrigatorio(dados, "registro")
    uf_registro = texto_obrigatorio(dados, "uf_registro")

    if not nome:
        return jsonify({"erro": "Nome é obrigatório!"}), 400
    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400
    if not email_valido(email):
        return jsonify({"erro": "E-mail deve conter @."}), 400
    if not isinstance(senha, str) or not senha:
        return jsonify({"erro": "Senha é obrigatória!"}), 400
    if len(senha) < 8:
        return jsonify({"erro": "Senha deve ter pelo menos 8 caracteres!"}), 400
    if not profissao:
        return jsonify({"erro": "Profissão é obrigatória!"}), 400
    if not registro:
        return jsonify({"erro": "Registro é obrigatório!"}), 400
    if not uf_registro:
        return jsonify({"erro": "UF do registro é obrigatória!"}), 400

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                "INSERT INTO usuarios (nome, email, senha_hash) VALUES (%s, %s, %s)",
                (nome, email, senha_hash),
            )
            usuario_id = cursor.lastrowid
            cursor.execute(
                """
                INSERT INTO profissionais (usuario_id, profissao, registro, uf_registro)
                VALUES (%s, %s, %s, %s)
                """,
                (usuario_id, profissao, registro, uf_registro),
            )
    except Exception as erro:
        if erro_chave_duplicada(erro):
            return jsonify({"erro": "E-mail ou registro já cadastrado!"}), 409
        logger.exception("Erro ao cadastrar profissional")
        return jsonify({"erro": "Não foi possível cadastrar o profissional!"}), 500

    return jsonify({"mensagem": "Profissional cadastrado com sucesso!"}), 201


@usuario.route("/login", methods=["POST"])
def login():
    dados = dados_json()
    email = texto_obrigatorio(dados, "email").lower()
    senha = dados.get("senha")

    if not email or not isinstance(senha, str) or not senha:
        return jsonify({"erro": "E-mail e senha são obrigatórios!"}), 400

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                """
                SELECT
                    u.id,
                    u.nome,
                    u.email,
                    u.senha_hash,
                    EXISTS(
                        SELECT 1 FROM profissionais p WHERE p.usuario_id = u.id
                    ) AS eh_profissional
                FROM usuarios u
                WHERE u.email = %s
                """,
                (email,),
            )
            usuario_encontrado = cursor.fetchone()
    except Exception:
        logger.exception("Erro ao buscar usuário para login")
        return jsonify({"erro": "Não foi possível realizar o login!"}), 500

    if not usuario_encontrado:
        return jsonify({"erro": "E-mail ou senha incorretos!"}), 401

    senha_hash = usuario_encontrado["senha_hash"]
    senha_hash = senha_hash.encode("utf-8") if isinstance(senha_hash, str) else senha_hash
    try:
        senha_correta = bcrypt.checkpw(senha.encode("utf-8"), senha_hash)
    except (TypeError, ValueError):
        logger.exception("Hash de senha inválido para o usuário")
        return jsonify({"erro": "Não foi possível realizar o login!"}), 500

    if not senha_correta:
        return jsonify({"erro": "E-mail ou senha incorretos!"}), 401

    segredo_jwt = os.getenv("JWT_SECRET")
    if not segredo_jwt:
        logger.error("JWT_SECRET não configurado")
        return jsonify({"erro": "Não foi possível realizar o login!"}), 500

    token = jwt.encode(
        {"usuario_id": usuario_encontrado["id"], "exp": int(time.time()) + 7200},
        segredo_jwt,
        algorithm="HS256",
    )

    return jsonify(
        {
            "mensagem": "Login realizado com sucesso!",
            "token": token,
            "usuario": {
                "id": usuario_encontrado["id"],
                "nome": usuario_encontrado["nome"],
                "email": usuario_encontrado["email"],
                "eh_profissional": bool(usuario_encontrado["eh_profissional"]),
            },
        }
    ), 200


@usuario.route("/recuperar-senha", methods=["POST"])
def recuperar_senha():
    dados = dados_json()
    email = texto_obrigatorio(dados, "email").lower()

    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400
    if not email_valido(email):
        return jsonify({"erro": "E-mail deve conter @."}), 400

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute("SELECT id FROM usuarios WHERE email = %s", (email,))
            usuario_encontrado = cursor.fetchone()
    except Exception:
        logger.exception("Erro ao buscar usuário para recuperação de senha")
        return resposta_recuperacao_indisponivel()

    # A mesma resposta evita revelar se determinado e-mail possui conta.
    if not usuario_encontrado:
        return jsonify(
            {"mensagem": "Se o e-mail estiver cadastrado, você receberá um código."}
        ), 202

    codigo = str(secrets.randbelow(900000) + 100000)
    expira_em = int(time.time()) + TEMPO_EXPIRACAO_CODIGO

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                "DELETE FROM recuperacoes_senha WHERE usuario_id = %s",
                (usuario_encontrado["id"],),
            )
            cursor.execute(
                """
                INSERT INTO recuperacoes_senha
                    (usuario_id, codigo, expira_em, tentativas, verificado)
                VALUES (%s, %s, %s, 0, 0)
                """,
                (
                    usuario_encontrado["id"],
                    hash_codigo_recuperacao(codigo),
                    expira_em,
                ),
            )
            recuperacao_id = cursor.lastrowid
    except Exception:
        logger.exception("Erro ao criar código de recuperação")
        return resposta_recuperacao_indisponivel()

    try:
        agendar_envio_codigo(email, codigo, recuperacao_id)
    except Exception:
        logger.exception("Não foi possível agendar o e-mail de recuperação")
        try:
            invalidar_recuperacao(recuperacao_id)
        except Exception:
            logger.exception("Não foi possível invalidar código não agendado")
        return resposta_recuperacao_indisponivel()

    return jsonify(
        {"mensagem": "Se o e-mail estiver cadastrado, você receberá um código."}
    ), 202


@usuario.route("/verificar-codigo", methods=["POST"])
def verificar_codigo():
    dados = dados_json()
    email = texto_obrigatorio(dados, "email").lower()
    codigo = codigo_recebido_valido(dados.get("codigo"))

    if not email or not codigo:
        return jsonify({"erro": "E-mail e código de seis dígitos são obrigatórios!"}), 400

    try:
        with sessao_banco() as (_, cursor):
            recuperacao = buscar_recuperacao(cursor, email)

            if not recuperacao:
                return jsonify({"erro": "Código não encontrado!"}), 400

            if int(time.time()) > int(recuperacao["expira_em"]):
                cursor.execute(
                    "DELETE FROM recuperacoes_senha WHERE id = %s",
                    (recuperacao["id"],),
                )
                return jsonify({"erro": "Código expirado!"}), 400

            if int(recuperacao["tentativas"]) >= LIMITE_TENTATIVAS_CODIGO:
                return jsonify({"erro": "Código bloqueado por excesso de tentativas!"}), 429

            if not codigo_confere(codigo, recuperacao["codigo"]):
                if registrar_tentativa_invalida(cursor, recuperacao):
                    return jsonify(
                        {"erro": "Código bloqueado por excesso de tentativas!"}
                    ), 429
                return jsonify({"erro": "Código inválido!"}), 400

            if not recuperacao["verificado"]:
                cursor.execute(
                    "UPDATE recuperacoes_senha SET verificado = 1 WHERE id = %s",
                    (recuperacao["id"],),
                )
    except Exception:
        logger.exception("Erro ao verificar código de recuperação")
        return resposta_recuperacao_indisponivel()

    return jsonify({"mensagem": "Código confirmado com sucesso!"}), 200


@usuario.route("/redefinir-senha", methods=["POST"])
def redefinir_senha():
    dados = dados_json()
    email = texto_obrigatorio(dados, "email").lower()
    codigo = codigo_recebido_valido(dados.get("codigo"))
    nova_senha = dados.get("nova_senha")

    if not email or not codigo or not isinstance(nova_senha, str) or not nova_senha:
        return jsonify(
            {"erro": "E-mail, código e nova senha são obrigatórios!"}
        ), 400
    if len(nova_senha) < 8:
        return jsonify({"erro": "Senha deve ter pelo menos 8 caracteres!"}), 400

    try:
        with sessao_banco() as (_, cursor):
            recuperacao = buscar_recuperacao(cursor, email)

            if not recuperacao:
                return jsonify({"erro": "Código não encontrado!"}), 400

            if int(time.time()) > int(recuperacao["expira_em"]):
                cursor.execute(
                    "DELETE FROM recuperacoes_senha WHERE id = %s",
                    (recuperacao["id"],),
                )
                return jsonify({"erro": "Código expirado!"}), 400

            if int(recuperacao["tentativas"]) >= LIMITE_TENTATIVAS_CODIGO:
                return jsonify({"erro": "Código bloqueado por excesso de tentativas!"}), 429

            if not codigo_confere(codigo, recuperacao["codigo"]):
                if registrar_tentativa_invalida(cursor, recuperacao):
                    return jsonify(
                        {"erro": "Código bloqueado por excesso de tentativas!"}
                    ), 429
                return jsonify({"erro": "Código inválido!"}), 400

            if not recuperacao["verificado"]:
                return jsonify({"erro": "O código ainda não foi confirmado!"}), 400

            senha_hash = bcrypt.hashpw(
                nova_senha.encode("utf-8"), bcrypt.gensalt()
            ).decode("utf-8")
            cursor.execute(
                "UPDATE usuarios SET senha_hash = %s WHERE email = %s",
                (senha_hash, email),
            )
            cursor.execute(
                "DELETE FROM recuperacoes_senha WHERE id = %s",
                (recuperacao["id"],),
            )
    except Exception:
        logger.exception("Erro ao redefinir senha")
        return resposta_recuperacao_indisponivel()

    return jsonify({"mensagem": "Senha redefinida com sucesso!"}), 200