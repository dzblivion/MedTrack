import bcrypt
from config.database import banco
from flask import Blueprint, request

usuario = Blueprint("usuario", __name__)


@usuario.route("/usuario", methods=["POST"])
def cadastrar_usuario():
    dados = request.get_json()
    nome = dados.get("nome")
    email = dados.get("email")
    senha = dados.get("senha")

    senha_hash = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt())

    conexao = banco()
    cursor = conexao.cursor()

    sql = """INSERT INTO usuarios (nome, email, senha_hash) VALUES (%s, %s, %s)"""

    cursor.execute(sql, (nome, email, senha_hash.decode("utf-8")))

    conexao.commit()

    cursor.close()
    conexao.close()

    return {"mensagem": "Usuário cadastrado com sucesso!"}, 201
