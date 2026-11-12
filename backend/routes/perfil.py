import logging
import re
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from flask import Blueprint, jsonify, request, send_file
from PIL import Image, ImageOps, UnidentifiedImageError
from routes.usuario import obter_usuario_id, sessao_banco

perfil = Blueprint("perfil", __name__)
logger = logging.getLogger(__name__)

PASTA_FOTOS = Path("/app/uploads/perfis")
TAMANHO_MAXIMO = 5 * 1024 * 1024
PIXELS_MAXIMOS = 12_000_000


def remover_arquivo_foto(nome):
    """Remove somente arquivos com o padrão gerado pela aplicação."""
    if not nome or not re.fullmatch(r"\d+_[0-9a-f]{32}\.jpg", nome):
        return

    try:
        (PASTA_FOTOS / nome).unlink(missing_ok=True)
    except OSError:
        logger.exception("Erro ao remover arquivo de foto")


def processar_imagem(conteudo):
    """Valida a imagem e gera uma versão JPEG sem metadados EXIF."""
    with Image.open(BytesIO(conteudo)) as imagem:
        if imagem.format not in ("JPEG", "PNG", "WEBP"):
            raise ValueError("Formato de imagem não permitido")

        if imagem.width * imagem.height > PIXELS_MAXIMOS:
            raise ValueError("Resolução da imagem muito alta")

        imagem = ImageOps.exif_transpose(imagem)
        imagem.thumbnail((1024, 1024))

        # Mantém fundo branco em imagens transparentes.
        imagem_rgba = imagem.convert("RGBA")
        fundo = Image.new("RGB", imagem_rgba.size, "white")
        fundo.paste(imagem_rgba, mask=imagem_rgba.getchannel("A"))

        resultado = BytesIO()
        fundo.save(resultado, format="JPEG", quality=85)

        return resultado.getvalue()

@perfil.route("/usuarios/me/foto", methods=["PUT"])
def atualizar_foto_perfil():
    usuario_id = obter_usuario_id()

    if usuario_id is None:
        return jsonify({"erro": "Não autorizado!"}), 401

    arquivo = request.files.get("foto")

    if arquivo is None or not arquivo.filename:
        return jsonify({"erro": "Selecione uma foto!"}), 400

    conteudo = arquivo.stream.read(TAMANHO_MAXIMO + 1)

    if len(conteudo) > TAMANHO_MAXIMO:
        return jsonify({"erro": "A foto deve ter até 5 MB!"}), 413

    try:
        imagem = processar_imagem(conteudo)
    except (
        UnidentifiedImageError,
        Image.DecompressionBombError,
        ValueError,
        OSError,
    ):
        return jsonify({
            "erro": "Imagem inválida! Utilize JPG, PNG ou WebP."
        }), 400

    nome_arquivo = f"{usuario_id}_{uuid4().hex}.jpg"
    caminho = PASTA_FOTOS / nome_arquivo

    try:
        PASTA_FOTOS.mkdir(parents=True, exist_ok=True)
        caminho.write_bytes(imagem)
    except OSError:
        remover_arquivo_foto(nome_arquivo)
        logger.exception("Erro ao salvar foto no armazenamento")
        return jsonify({"erro": "Não foi possível salvar a foto!"}), 500

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                """
                SELECT foto_perfil
                FROM usuarios
                WHERE id = %s
                FOR UPDATE
                """,
                (usuario_id,),
            )

            usuario_encontrado = cursor.fetchone()

            if not usuario_encontrado:
                remover_arquivo_foto(nome_arquivo)
                return jsonify({"erro": "Usuário não encontrado!"}), 404

            foto_anterior = usuario_encontrado["foto_perfil"]

            cursor.execute(
                """
                UPDATE usuarios
                SET foto_perfil = %s
                WHERE id = %s
                """,
                (nome_arquivo, usuario_id),
            )

    except Exception:
        remover_arquivo_foto(nome_arquivo)
        logger.exception("Erro ao atualizar foto no banco")
        return jsonify({"erro": "Não foi possível atualizar a foto!"}), 500

    # Remove a foto antiga após atualizar o banco.
    remover_arquivo_foto(foto_anterior)

    return jsonify({
        "mensagem": "Foto de perfil atualizada com sucesso!",
        "foto_perfil": nome_arquivo,
    }), 200

@perfil.route("/usuarios/me/foto", methods=["GET"])
def buscar_foto_perfil():
    usuario_id = obter_usuario_id()

    if usuario_id is None:
        return jsonify({"erro": "Não autorizado!"}), 401

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                """
                SELECT foto_perfil
                FROM usuarios
                WHERE id = %s
                """,
                (usuario_id,),
            )

            usuario_encontrado = cursor.fetchone()

    except Exception:
        logger.exception("Erro ao buscar foto de perfil")
        return jsonify({"erro": "Não foi possível buscar a foto!"}), 500

    if not usuario_encontrado:
        return jsonify({"erro": "Usuário não encontrado!"}), 404

    nome_arquivo = usuario_encontrado["foto_perfil"]

    if not nome_arquivo:
        return jsonify({"erro": "Usuário não possui foto de perfil!"}), 404

    # Impede a leitura de arquivos fora da pasta de fotos.
    if not re.fullmatch(r"\d+_[0-9a-f]{32}\.jpg", nome_arquivo):
        return jsonify({"erro": "Foto de perfil indisponível!"}), 404

    caminho = PASTA_FOTOS / nome_arquivo

    if not caminho.is_file():
        return jsonify({"erro": "Arquivo de foto não encontrado!"}), 404

    resposta = send_file(caminho, mimetype="image/jpeg")
    resposta.headers["Cache-Control"] = "no-store"

    return resposta

@perfil.route("/usuarios/me/foto", methods=["DELETE"])
def remover_foto_perfil():
    usuario_id = obter_usuario_id()

    if usuario_id is None:
        return jsonify({"erro": "Não autorizado!"}), 401

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                """
                SELECT foto_perfil
                FROM usuarios
                WHERE id = %s
                FOR UPDATE
                """,
                (usuario_id,),
            )

            usuario_encontrado = cursor.fetchone()

            if not usuario_encontrado:
                return jsonify({"erro": "Usuário não encontrado!"}), 404

            foto_anterior = usuario_encontrado["foto_perfil"]

            cursor.execute(
                """
                UPDATE usuarios
                SET foto_perfil = NULL
                WHERE id = %s
                """,
                (usuario_id,),
            )

    except Exception:
        logger.exception("Erro ao remover foto de perfil")
        return jsonify({"erro": "Não foi possível remover a foto!"}), 500

    remover_arquivo_foto(foto_anterior)

    return jsonify({
        "mensagem": "Foto de perfil removida com sucesso!"
    }), 200
