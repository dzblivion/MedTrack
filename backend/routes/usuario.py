import os
import secrets
import time

import bcrypt
import jwt
from config.database import banco
from config.mail import mail
from flask import Blueprint, jsonify, request
from flask_mail import Message

usuario = Blueprint("usuario", __name__)


def enviar_codigo_recuperacao(email: str, usuario_id: int):
    codigo = str(secrets.randbelow(900000) + 100000)
    expira_em = int(time.time()) + 600

    msg = Message(
        subject="Código para redefinir sua senha - MedTrack",
        sender="dsgncece@gmail.com",
        recipients=[email],
    )

    msg.body = (
        f"Seu código para redefinir a senha é: {codigo}.\n\n"
        "Ele é válido por 10 minutos."
    )

    try:
        conexao = banco()
        cursor = conexao.cursor()

        # remove códigos anteriores desse usuário
        sql_delete = """
            DELETE FROM recuperacoes_senha
            WHERE usuario_id = %s
        """

        cursor.execute(sql_delete, (usuario_id,))

        # salva o novo código
        sql_insert = """
            INSERT INTO recuperacoes_senha
            (usuario_id, codigo, expira_em)
            VALUES (%s, %s, %s)
        """

        cursor.execute(sql_insert, (usuario_id, codigo, expira_em))

        conexao.commit()

        cursor.close()
        conexao.close()

        mail.send(msg)

        return True

    except Exception as e:
        print(e)

        if "conexao" in locals():
            conexao.rollback()
            cursor.close()
            conexao.close()

        return False


@usuario.route("/cadastrar-usuario", methods=["POST"])
def cadastrar_usuario():
    dados = request.get_json()

    if not dados:
        return jsonify({"erro": "Dados de cadastro são obrigatórios!"}), 400

    nome = dados.get("nome")
    email = dados.get("email")
    senha = dados.get("senha")

    if not nome:
        return jsonify({"erro": "Nome é obrigatório!"}), 400

    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400

    if "@" not in email:
        return jsonify({"erro": "E-mail deve conter @."}), 400

    if not senha:
        return jsonify({"erro": "Senha é obrigatória!"}), 400

    if len(senha) < 8:
        return jsonify({"erro": "Senha deve ter pelo menos 8 caracteres!"}), 400

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt())

    conexao = banco()
    cursor = conexao.cursor()

    sql = """INSERT INTO usuarios (nome, email, senha_hash) VALUES (%s, %s, %s)"""

    cursor.execute(sql, (nome, email, senha_hash.decode("utf-8")))

    conexao.commit()

    cursor.close()
    conexao.close()

    return jsonify({"mensagem": "Usuário cadastrado com sucesso!"}), 201


@usuario.route("/cadastrar-profissional", methods=["POST"])
def cadastrar_profissional():
    dados = request.get_json()

    if not dados:
        return jsonify({"erro": "Dados de cadastro são obrigatórios!"}), 400

    nome = dados.get("nome")
    email = dados.get("email")
    senha = dados.get("senha")
    profissao = dados.get("profissao")
    registro = dados.get("registro")
    uf_registro = dados.get("uf_registro")

    if not nome:
            return jsonify({"erro": "Nome é obrigatório!"}), 400
    
    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400
    
    if "@" not in email:
        return jsonify({"erro": "E-mail deve conter @."}), 400
    
    if not senha:
        return jsonify({"erro": "Senha é obrigatória!"}), 400
    
    if len(senha) < 8:
       return jsonify({"erro": "Senha deve ter pelo menos 8 caracteres!"}), 400

    if profissao is None or profissao.strip() == "":
        return jsonify({"erro": "Profissão é obrigatória!"}), 400

    if registro is None or registro.strip() == "":
        return jsonify({"erro": "Registro é obrigatório!"}), 400

    if uf_registro is None or uf_registro.strip() == "":
        return jsonify({"erro": "UF do registro é obrigatória!"}), 400

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt())

    conexao = banco()
    cursor = conexao.cursor()

    sql = """INSERT INTO usuarios (nome, email, senha_hash) VALUES (%s, %s, %s)"""

    cursor.execute(sql, (nome, email, senha_hash.decode("utf-8")))

    usuario_id = cursor.lastrowid

    sql_profissional = """INSERT INTO profissionais (usuario_id, profissao, registro, uf_registro) VALUES (%s, %s, %s, %s)"""

    cursor.execute(sql_profissional, (usuario_id, profissao, registro, uf_registro))

    conexao.commit()

    cursor.close()
    conexao.close()

    return jsonify({"mensagem": "Profissional cadastrado com sucesso!"}), 201


@usuario.route("/login", methods=["POST"])
def login():
    dados = request.get_json()

    email = dados.get("email")
    senha = dados.get("senha")

    if not email or not senha:
        return jsonify({"erro": "E-mail e senha são obrigatórios!"}), 400

    conexao = banco()
    cursor = conexao.cursor()

    sql = """
        SELECT id, nome, email, senha_hash
        FROM usuarios
        WHERE email = %s
    """

    cursor.execute(sql, (email,))
    usuario_encontrado = cursor.fetchone()

    cursor.close()
    conexao.close()

    if not usuario_encontrado:
        return jsonify({"erro": "E-mail ou senha incorretos!"}), 401

    senha_hash = usuario_encontrado["senha_hash"]

    senha_correta = bcrypt.checkpw(senha.encode("utf-8"), senha_hash.encode("utf-8"))

    if not senha_correta:
        return jsonify({"erro": "E-mail ou senha incorretos!"}), 401

    payload = {"usuario_id": usuario_encontrado["id"], "exp": int(time.time()) + 7200}

    token = jwt.encode(payload, os.getenv("JWT_SECRET"), algorithm="HS256")

    return jsonify(
        {
            "mensagem": "Login realizado com sucesso!",
            "token": token,
            "usuario": {
                "id": usuario_encontrado["id"],
                "nome": usuario_encontrado["nome"],
                "email": usuario_encontrado["email"],
            },
        }
    ), 200


@usuario.route("/recuperar-senha", methods=["POST"])
def recuperar_senha():
    dados = request.get_json()
    email = dados.get("email")

    if not email:
        return jsonify({"erro": "E-mail é obrigatório!"}), 400

    conexao = banco()
    cursor = conexao.cursor()

    sql = "SELECT id FROM usuarios WHERE email = %s"
    cursor.execute(sql, (email,))

    usuario_encontrado = cursor.fetchone()

    cursor.close()
    conexao.close()

    if not usuario_encontrado:
        return jsonify({"erro": "E-mail não encontrado!"}), 404

    usuario_id = usuario_encontrado["id"]

    if enviar_codigo_recuperacao(email, usuario_id):
        return jsonify({"mensagem": "Código enviado para o e-mail!"}), 200

    return jsonify({"erro": "Não foi possível enviar o código!"}), 500


@usuario.route("/verificar-codigo", methods=["POST"])
def verificar_codigo():
    dados = request.get_json()

    email = dados.get("email")
    codigo = dados.get("codigo")

    if not email or not codigo:
        return jsonify({"erro": "E-mail e código são obrigatórios!"}), 400

    conexao = banco()
    cursor = conexao.cursor()

    sql = """
        SELECT
            r.id,
            r.codigo,
            r.expira_em,
            r.verificado
        FROM recuperacoes_senha r
        INNER JOIN usuarios u
            ON r.usuario_id = u.id
        WHERE u.email = %s
        ORDER BY r.id DESC
        LIMIT 1
    """

    cursor.execute(sql, (email,))

    recuperacao = cursor.fetchone()

    if not recuperacao:
        cursor.close()
        conexao.close()

        return jsonify({"erro": "Código não encontrado!"}), 400

    recuperacao_id = recuperacao["id"]
    codigo_salvo = recuperacao["codigo"]
    expira_em = recuperacao["expira_em"]

    if int(time.time()) > expira_em:
        cursor.close()
        conexao.close()

        return jsonify({"erro": "Código expirado!"}), 400

    if str(codigo) != str(codigo_salvo):
        cursor.close()
        conexao.close()

        return jsonify({"erro": "Código inválido!"}), 400

    sql_update = """
        UPDATE recuperacoes_senha
        SET verificado = 1
        WHERE id = %s
    """

    cursor.execute(sql_update, (recuperacao_id,))

    conexao.commit()

    cursor.close()
    conexao.close()

    return jsonify({"mensagem": "Código confirmado com sucesso!"}), 200


@usuario.route("/redefinir-senha", methods=["POST"])
def redefinir_senha():
    dados = request.get_json()

    email = dados.get("email")
    codigo = dados.get("codigo")
    nova_senha = dados.get("nova_senha")

    if not email or not codigo or not nova_senha:
        return jsonify({"erro": "E-mail, código e nova senha são obrigatórios!"}), 400

    conexao = banco()
    cursor = conexao.cursor()

    sql = """
        SELECT
            r.id,
            r.codigo,
            r.expira_em,
            r.verificado
        FROM recuperacoes_senha r
        INNER JOIN usuarios u
            ON r.usuario_id = u.id
        WHERE u.email = %s
        ORDER BY r.id DESC
        LIMIT 1
    """

    cursor.execute(sql, (email,))

    recuperacao = cursor.fetchone()

    if not recuperacao:
        cursor.close()
        conexao.close()

        return jsonify({"erro": "Código não encontrado!"}), 400

    recuperacao_id = recuperacao["id"]
    codigo_salvo = recuperacao["codigo"]
    expira_em = recuperacao["expira_em"]
    verificado = recuperacao["verificado"]

    if int(time.time()) > expira_em:
        cursor.close()
        conexao.close()

        return jsonify({"erro": "Código expirado!"}), 400

    if str(codigo) != str(codigo_salvo):
        cursor.close()
        conexao.close()

        return jsonify({"erro": "Código inválido!"}), 400

    if not verificado:
        cursor.close()
        conexao.close()

        return jsonify({"erro": "O código ainda não foi confirmado!"}), 400

    senha_hash = bcrypt.hashpw(nova_senha.encode("utf-8"), bcrypt.gensalt())

    sql_update_senha = """
        UPDATE usuarios
        SET senha_hash = %s
        WHERE email = %s
    """

    cursor.execute(sql_update_senha, (senha_hash.decode("utf-8"), email))

    # Remove a recuperação depois que a senha foi alterada
    sql_delete = """
        DELETE FROM recuperacoes_senha
        WHERE id = %s
    """

    cursor.execute(sql_delete, (recuperacao_id,))

    conexao.commit()

    cursor.close()
    conexao.close()

    return jsonify({"mensagem": "Senha redefinida com sucesso!"}), 200
