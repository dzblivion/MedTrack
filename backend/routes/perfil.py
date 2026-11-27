import logging
import os
import re
from io import BytesIO
from pathlib import Path
from uuid import uuid4

import bcrypt
from flask import Blueprint, jsonify, request, send_file
from PIL import Image, ImageOps, UnidentifiedImageError
from routes.usuario import obter_usuario_id, sessao_banco

perfil = Blueprint("perfil", __name__)
logger = logging.getLogger(__name__)

PASTA_FOTOS_PADRAO = Path(__file__).resolve().parents[1] / "uploads" / "perfis"
PASTA_FOTOS = Path(
    os.getenv("FOTOS_PERFIL_DIR", str(PASTA_FOTOS_PADRAO))
).expanduser()
TAMANHO_MAXIMO = 5 * 1024 * 1024
MARGEM_MULTIPART = 64 * 1024
TAMANHO_MAXIMO_REQUISICAO = TAMANHO_MAXIMO + MARGEM_MULTIPART
PIXELS_MAXIMOS = 12_000_000
INTERVALO_MINIMO_UPLOAD_SEGUNDOS = 60


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


def resposta_limite_upload(espera_segundos):
    resposta = jsonify(
        {
            "erro": "Aguarde antes de trocar a foto novamente.",
            "aguarde_segundos": espera_segundos,
        }
    )
    resposta.status_code = 429
    resposta.headers["Retry-After"] = str(espera_segundos)
    return resposta


def buscar_espera_upload(cursor, usuario_id, bloquear=False):
    bloqueio = " FOR UPDATE" if bloquear else ""
    cursor.execute(
        f"""
        SELECT
            foto_perfil,
            GREATEST(
                0,
                %s - TIMESTAMPDIFF(
                    SECOND,
                    foto_perfil_atualizada_em,
                    CURRENT_TIMESTAMP
                )
            ) AS espera_segundos
        FROM usuarios
        WHERE id = %s{bloqueio}
        """,
        (INTERVALO_MINIMO_UPLOAD_SEGUNDOS, usuario_id),
    )
    return cursor.fetchone()


@perfil.route("/usuarios/me", methods=["PATCH"])
def atualizar_nome_perfil():
    usuario_id = obter_usuario_id()
    if usuario_id is None:
        return jsonify({"erro": "Não autorizado!"}), 401

    dados = request.get_json(silent=True)
    nome = dados.get("nome") if isinstance(dados, dict) else None
    if not isinstance(nome, str) or not nome.strip():
        return jsonify({"erro": "Informe um nome válido!"}), 400
    nome = nome.strip()
    if len(nome) > 120:
        return jsonify({"erro": "O nome deve ter no máximo 120 caracteres!"}), 400

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute("SELECT id FROM usuarios WHERE id = %s FOR UPDATE", (usuario_id,))
            if not cursor.fetchone():
                return jsonify({"erro": "Usuário não encontrado!"}), 404
            cursor.execute("UPDATE usuarios SET nome = %s WHERE id = %s", (nome, usuario_id))
    except Exception:
        logger.exception("Erro ao atualizar nome do perfil")
        return jsonify({"erro": "Não foi possível atualizar o nome!"}), 500

    return jsonify({"mensagem": "Nome atualizado com sucesso!", "nome": nome}), 200


@perfil.route("/usuarios/me", methods=["DELETE"])
def excluir_conta():
    usuario_id = obter_usuario_id()
    if usuario_id is None:
        return jsonify({"erro": "Não autorizado!"}), 401

    dados = request.get_json(silent=True)
    senha = dados.get("senha") if isinstance(dados, dict) else None
    if not isinstance(senha, str) or not senha:
        return jsonify({"erro": "Informe sua senha atual!"}), 400

    try:
        senha_bytes = senha.encode("utf-8")
        if len(senha_bytes) > 72:
            return jsonify({"erro": "Senha incorreta!"}), 403

        with sessao_banco() as (_, cursor):
            cursor.execute(
                "SELECT email, senha_hash, foto_perfil FROM usuarios WHERE id = %s FOR UPDATE",
                (usuario_id,),
            )
            usuario_encontrado = cursor.fetchone()
            if not usuario_encontrado:
                return jsonify({"erro": "Usuário não encontrado!"}), 404

            senha_hash = usuario_encontrado["senha_hash"]
            if isinstance(senha_hash, str):
                senha_hash = senha_hash.encode("utf-8")
            if not bcrypt.checkpw(senha_bytes, senha_hash):
                return jsonify({"erro": "Senha incorreta!"}), 403

            # Os compartilhamentos não possuem exclusão em cascata no esquema.
            cursor.execute(
                """
                DELETE FROM compartilhamentos
                WHERE paciente_usuario_id = %s OR profissional_usuario_id = %s
                   OR tratamento_id IN (SELECT id FROM tratamentos WHERE usuario_id = %s)
                """,
                (usuario_id, usuario_id, usuario_id),
            )
            cursor.execute(
                "DELETE FROM confirmacoes_cadastro WHERE email = %s",
                (usuario_encontrado["email"],),
            )
            cursor.execute("DELETE FROM usuarios WHERE id = %s", (usuario_id,))
            foto_anterior = usuario_encontrado["foto_perfil"]
    except Exception:
        logger.exception("Erro ao excluir conta")
        return jsonify({"erro": "Não foi possível excluir a conta!"}), 500

    # O banco já confirmou a transação; uma falha no arquivo é registrada no log.
    remover_arquivo_foto(foto_anterior)
    return jsonify({"mensagem": "Conta excluída com sucesso!"}), 200


@perfil.route("/usuarios/me/foto", methods=["PUT"])
def atualizar_foto_perfil():
    usuario_id = obter_usuario_id()

    if usuario_id is None:
        return jsonify({"erro": "Não autorizado!"}), 401

    # Limite específico desta rota, aplicado antes de o multipart ser processado.
    request.max_content_length = TAMANHO_MAXIMO_REQUISICAO

    # A consulta antecipada evita processar imagens caras de quem ainda está no
    # intervalo de espera. A checagem sob bloqueio abaixo continua sendo a fonte
    # de verdade para requisições concorrentes.
    try:
        with sessao_banco() as (_, cursor):
            usuario_encontrado = buscar_espera_upload(cursor, usuario_id)
    except Exception:
        logger.exception("Erro ao verificar limite de upload da foto")
        return jsonify({"erro": "Não foi possível atualizar a foto!"}), 500

    if not usuario_encontrado:
        return jsonify({"erro": "Usuário não encontrado!"}), 404

    espera_segundos = int(usuario_encontrado["espera_segundos"] or 0)
    if espera_segundos:
        return resposta_limite_upload(espera_segundos)

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
            usuario_encontrado = buscar_espera_upload(
                cursor,
                usuario_id,
                bloquear=True,
            )

            if not usuario_encontrado:
                remover_arquivo_foto(nome_arquivo)
                return jsonify({"erro": "Usuário não encontrado!"}), 404

            espera_segundos = int(usuario_encontrado["espera_segundos"] or 0)
            if espera_segundos:
                remover_arquivo_foto(nome_arquivo)
                return resposta_limite_upload(espera_segundos)

            foto_anterior = usuario_encontrado["foto_perfil"]

            cursor.execute(
                """
                UPDATE usuarios
                SET
                    foto_perfil = %s,
                    foto_perfil_atualizada_em = CURRENT_TIMESTAMP
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
