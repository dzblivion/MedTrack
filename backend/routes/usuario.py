import hashlib
import hmac
import logging
import os
import re
import secrets
import time
from contextlib import contextmanager
from html import escape
from threading import Thread

import bcrypt
import jwt
from config.database import banco
from config.mail import mail
from flask import Blueprint, abort, current_app, jsonify, request
from flask_mail import Message

usuario = Blueprint("usuario", __name__)
logger = logging.getLogger(__name__)

TEMPO_EXPIRACAO_CODIGO = 10 * 60
LIMITE_TENTATIVAS_CODIGO = 5
INTERVALO_REENVIO_CODIGO = 60


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
    """Valida o formato básico sem tentar comprovar a existência da caixa postal."""
    if not isinstance(email, str) or len(email) > 150:
        return False

    return (
        re.fullmatch(
            r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
            r"@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
            r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+",
            email,
        )
        is not None
    )


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


def segredo_codigo_cadastro():
    """Chave própria para códigos de cadastro, com fallback seguro."""
    segredo = (
        os.getenv("CADASTRO_CODIGO_SECRET")
        or os.getenv("RECUPERACAO_CODIGO_SECRET")
        or os.getenv("JWT_SECRET")
    )
    if not segredo:
        raise RuntimeError(
            "CADASTRO_CODIGO_SECRET, RECUPERACAO_CODIGO_SECRET ou JWT_SECRET não configurado"
        )
    return segredo


def hash_codigo_cadastro(codigo):
    """Mantém os códigos de confirmação de cadastro fora do banco em texto puro."""
    mensagem = f"confirmacao-cadastro:{codigo}".encode()
    return hmac.new(
        segredo_codigo_cadastro().encode("utf-8"),
        mensagem,
        hashlib.sha256,
    ).hexdigest()


def codigo_recebido_valido(codigo):
    codigo = str(codigo).strip() if codigo is not None else ""
    return codigo if len(codigo) == 6 and codigo.isdigit() else None


def codigo_confere(codigo, codigo_hash):
    return hmac.compare_digest(hash_codigo_recuperacao(codigo), str(codigo_hash))


def codigo_cadastro_confere(codigo, codigo_hash):
    return hmac.compare_digest(hash_codigo_cadastro(codigo), str(codigo_hash))


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


def template_email_codigo(titulo, descricao, codigo, previa):
    titulo = escape(titulo)
    descricao = escape(descricao)
    codigo = escape(str(codigo))
    previa = escape(previa)

    logo_url = escape(os.getenv("MAIL_LOGO_URL", ""), quote=True)

    return f"""
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport"
              content="width=device-width, initial-scale=1">
    </head>

    <body style="
        margin:0;
        padding:32px 12px;
        background-color:#F7FAFA;
        font-family:'Poppins',Arial,Helvetica,sans-serif;
        color:#163A43;
    ">
        <div style="
            display:none !important;
            visibility:hidden;
            opacity:0;
            color:transparent;
            height:0;
            width:0;
            max-height:0;
            max-width:0;
            overflow:hidden;
            mso-hide:all;
        ">
            {previa}
            {"&#847;&zwnj;" * 100}
        </div>    
    
        <table role="presentation"
               align="center"
               cellpadding="0"
               cellspacing="0"
               width="100%"
               style="
                   max-width:520px;
                   background:#FFFFFF;
                   border-radius:16px;
                   overflow:hidden;
               ">

            
            <tr>
                <td align="center"
                    style="
                        background-color:#FFFFFF;
                        padding:28px 24px 24px;
                        border-bottom:1px solid #E5EEEE;
                    ">

                    <img
                        src="{logo_url}"
                        alt="MedTrack"
                        width="260"
                        style="
                            display:block;
                            width:260px;
                            max-width:100%;
                            height:auto;
                            margin:0 auto;
                            border:0;
                        "
                    >

                </td>
            </tr>


            <tr>
                <td style="padding:36px 30px;">

                    <h2 style="
                        margin:0 0 16px;
                        font-size:24px;
                        color:#163A43;
                    ">
                        {titulo}
                    </h2>

                    <p style="
                        margin:0 0 26px;
                        font-size:15px;
                        line-height:24px;
                        color:#506974;
                    ">
                        {descricao}
                    </p>

                    <table role="presentation"
                           width="100%"
                           cellpadding="0"
                           cellspacing="0"
                           style="
                               background:#DDF7F6;
                               border-radius:12px;
                           ">
                        <tr>
                            <td align="center"
                                style="padding:28px 12px;">

                                <p style="
                                    margin:0 0 12px;
                                    font-size:11px;
                                    font-weight:bold;
                                    letter-spacing:1px;
                                    color:#167C80;
                                ">
                                    SEU CÓDIGO DE VERIFICAÇÃO
                                </p>

                                <p style="
                                    margin:0;
                                    font-size:36px;
                                    font-weight:bold;
                                    letter-spacing:7px;
                                    color:#163A43;
                                ">
                                    {codigo}
                                </p>

                                <p style="
                                    margin:14px 0 0;
                                    font-size:12px;
                                    color:#506974;
                                ">
                                    Válido por 10 minutos
                                </p>

                            </td>
                        </tr>
                    </table>

                    <p style="
                        margin:26px 0;
                        font-size:14px;
                        line-height:23px;
                        color:#506974;
                    ">
                        Digite este código na tela de
                        verificação do aplicativo MedTrack.
                    </p>

                    <hr style="
                        border:0;
                        border-top:1px solid #DCE7E8;
                    ">

                    <p style="
                        margin:20px 0 0;
                        font-size:12px;
                        line-height:20px;
                        color:#68777A;
                    ">
                        Se você não solicitou este código,
                        ignore esta mensagem.
                        Nunca compartilhe seu código com outras pessoas.
                    </p>

                </td>
            </tr>

        </table>

        <p style="
            margin:24px auto 0;
            text-align:center;
            font-size:12px;
            color:#68777A;
        ">
            MedTrack · Seu tratamento em dia
        </p>

    </body>
    </html>
    """


def criar_mensagem_recuperacao(email, codigo):
    mensagem = Message(
        subject="Código para redefinir sua senha - MedTrack",
        sender=(
            "MedTrack",
            os.getenv("MAIL_DEFAULT_SENDER", "help.medtrack@gmail.com"),
        ),
        recipients=[email],
    )
    mensagem.body = (
        f"Seu código para redefinir a senha é: {codigo}.\n\n"
        "Ele é válido por 10 minutos."
    )
    mensagem.html = template_email_codigo(
        titulo="Recuperação de senha",
        descricao=(
            "Recebemos uma solicitação para redefinir "
            "a senha da sua conta MedTrack. "
            "Utilize o código abaixo para continuar."
        ),
        codigo=codigo,
        previa=(
            "Seu código para redefinir a senha está disponível. "
            "Abra o e-mail para visualizar."
        ),
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


def criar_mensagem_confirmacao_cadastro(email, codigo):
    mensagem = Message(
        subject="Confirme seu e-mail - MedTrack",
        sender=(
            "MedTrack",
            os.getenv("MAIL_DEFAULT_SENDER", "help.medtrack@gmail.com"),
        ),
        recipients=[email],
    )
    mensagem.body = (
        f"Seu código para confirmar o cadastro é: {codigo}.\n\n"
        "Ele é válido por 10 minutos. Não compartilhe este código."
    )
    mensagem.html = template_email_codigo(
        titulo="Confirme seu e-mail",
        descricao=(
            "Recebemos uma solicitação de cadastro no MedTrack. "
            "Utilize o código abaixo para confirmar seu e-mail "
            "e concluir seu cadastro."
        ),
        codigo=codigo,
        previa=(
            "Seu código de confirmação do MedTrack chegou. "
            "Abra o e-mail para visualizar."
        ),
    )
    return mensagem


def invalidar_confirmacao_cadastro(email, codigo_hash):
    """Remove apenas o código que não pôde ser enviado por SMTP."""
    with sessao_banco() as (_, cursor):
        cursor.execute(
            "DELETE FROM confirmacoes_cadastro WHERE email = %s AND codigo = %s",
            (email, codigo_hash),
        )


def enviar_confirmacao_cadastro_em_segundo_plano(app, email, codigo, codigo_hash):
    with app.app_context():
        try:
            mail.send(criar_mensagem_confirmacao_cadastro(email, codigo))
        except Exception:
            logger.exception("Falha ao enviar e-mail de confirmação de cadastro")
            try:
                invalidar_confirmacao_cadastro(email, codigo_hash)
            except Exception:
                logger.exception("Falha ao invalidar código de cadastro não enviado")


def agendar_confirmacao_cadastro(email, codigo, codigo_hash):
    app = current_app._get_current_object()
    Thread(
        target=enviar_confirmacao_cadastro_em_segundo_plano,
        args=(app, email, codigo, codigo_hash),
        daemon=True,
        name="envio-codigo-cadastro",
    ).start()


def buscar_confirmacao_cadastro(cursor, email):
    cursor.execute(
        """
        SELECT id, codigo, expira_em, tentativas
        FROM confirmacoes_cadastro
        WHERE email = %s
        LIMIT 1
        FOR UPDATE
        """,
        (email,),
    )
    return cursor.fetchone()


def validar_codigo_cadastro(cursor, email, codigo):
    """Valida o código sob bloqueio; o chamador deve consumi-lo na mesma transação."""
    confirmacao = buscar_confirmacao_cadastro(cursor, email)
    if not confirmacao:
        return "Código não encontrado ou expirado!"

    if int(time.time()) > int(confirmacao["expira_em"]):
        cursor.execute(
            "DELETE FROM confirmacoes_cadastro WHERE id = %s", (confirmacao["id"],)
        )
        return "Código expirado! Solicite um novo código."

    if int(confirmacao["tentativas"]) >= LIMITE_TENTATIVAS_CODIGO:
        return "Código bloqueado por excesso de tentativas! Solicite um novo código."

    if not codigo_cadastro_confere(codigo, confirmacao["codigo"]):
        tentativas = int(confirmacao["tentativas"]) + 1
        cursor.execute(
            "UPDATE confirmacoes_cadastro SET tentativas = %s WHERE id = %s",
            (tentativas, confirmacao["id"]),
        )
        if tentativas >= LIMITE_TENTATIVAS_CODIGO:
            return (
                "Código bloqueado por excesso de tentativas! Solicite um novo código."
            )
        return "Código inválido!"

    return None


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
        usuario_id = dados_token["usuario_id"]
    except (jwt.InvalidTokenError, KeyError, TypeError):
        return None

    if isinstance(usuario_id, bool) or not isinstance(usuario_id, int) or usuario_id <= 0:
        return None

    # Um token pode continuar assinado e vigente após a exclusão da conta.
    try:
        with sessao_banco() as (_, cursor):
            cursor.execute("SELECT id FROM usuarios WHERE id = %s", (usuario_id,))
            usuario_existe = cursor.fetchone() is not None
    except Exception:
        logger.exception("Erro ao verificar usuário autenticado")
        abort(503, description="Não foi possível verificar a autenticação agora.")

    return usuario_id if usuario_existe else None


@usuario.route("/solicitar-codigo-cadastro", methods=["POST"])
def solicitar_codigo_cadastro():
    dados = dados_json()
    email = texto_obrigatorio(dados, "email").lower()

    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400
    if not email_valido(email):
        return jsonify({"erro": "E-mail deve conter @."}), 400

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute("SELECT id FROM usuarios WHERE email = %s", (email,))
            if cursor.fetchone():
                return jsonify({"erro": "E-mail já cadastrado!"}), 409

            # Evita spam por reenvios: não substitui o código recém-enviado.
            cursor.execute(
                """
                SELECT id
                FROM confirmacoes_cadastro
                WHERE email = %s
                  AND criado_em > DATE_SUB(CURRENT_TIMESTAMP, INTERVAL %s SECOND)
                FOR UPDATE
                """,
                (email, INTERVALO_REENVIO_CODIGO),
            )
            if cursor.fetchone():
                return jsonify(
                    {
                        "erro": (
                            f"Aguarde {INTERVALO_REENVIO_CODIGO} segundos antes "
                            "de solicitar outro código."
                        )
                    }
                ), 429

            codigo = str(secrets.randbelow(900000) + 100000)
            codigo_hash = hash_codigo_cadastro(codigo)
            expira_em = int(time.time()) + TEMPO_EXPIRACAO_CODIGO
            cursor.execute(
                "DELETE FROM confirmacoes_cadastro WHERE email = %s", (email,)
            )
            cursor.execute(
                """
                INSERT INTO confirmacoes_cadastro (email, codigo, expira_em, tentativas)
                VALUES (%s, %s, %s, 0)
                """,
                (email, codigo_hash, expira_em),
            )
    except Exception:
        logger.exception("Erro ao criar código de confirmação de cadastro")
        return jsonify(
            {"erro": "Não foi possível enviar o código de confirmação!"}
        ), 500

    try:
        agendar_confirmacao_cadastro(email, codigo, codigo_hash)
    except Exception:
        logger.exception("Não foi possível agendar o e-mail de confirmação")
        try:
            invalidar_confirmacao_cadastro(email, codigo_hash)
        except Exception:
            logger.exception(
                "Não foi possível invalidar código de cadastro não agendado"
            )
        return jsonify(
            {"erro": "Não foi possível enviar o código de confirmação!"}
        ), 500

    return jsonify(
        {"mensagem": "Código de confirmação enviado para o e-mail informado."}
    ), 202


@usuario.route("/cadastrar-usuario", methods=["POST"])
def cadastrar_usuario():
    dados = dados_json()
    nome = texto_obrigatorio(dados, "nome")
    email = texto_obrigatorio(dados, "email").lower()
    senha = dados.get("senha")
    codigo = codigo_recebido_valido(dados.get("codigo"))

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
    if not codigo:
        return jsonify(
            {"erro": "Código de confirmação de seis dígitos é obrigatório!"}
        ), 400

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    try:
        with sessao_banco() as (_, cursor):
            erro_codigo = validar_codigo_cadastro(cursor, email, codigo)
            if erro_codigo:
                return jsonify({"erro": erro_codigo}), 400
            cursor.execute(
                "INSERT INTO usuarios (nome, email, senha_hash) VALUES (%s, %s, %s)",
                (nome, email, senha_hash),
            )
            cursor.execute(
                "DELETE FROM confirmacoes_cadastro WHERE email = %s", (email,)
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
    codigo = codigo_recebido_valido(dados.get("codigo"))

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
    if not codigo:
        return jsonify(
            {"erro": "Código de confirmação de seis dígitos é obrigatório!"}
        ), 400

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    try:
        with sessao_banco() as (_, cursor):
            erro_codigo = validar_codigo_cadastro(cursor, email, codigo)
            if erro_codigo:
                return jsonify({"erro": erro_codigo}), 400
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
            cursor.execute(
                "DELETE FROM confirmacoes_cadastro WHERE email = %s", (email,)
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
    senha_hash = (
        senha_hash.encode("utf-8") if isinstance(senha_hash, str) else senha_hash
    )
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
        return jsonify(
            {"erro": "E-mail e código de seis dígitos são obrigatórios!"}
        ), 400

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
                return jsonify(
                    {"erro": "Código bloqueado por excesso de tentativas!"}
                ), 429

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
        return jsonify({"erro": "E-mail, código e nova senha são obrigatórios!"}), 400
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
                return jsonify(
                    {"erro": "Código bloqueado por excesso de tentativas!"}
                ), 429

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
