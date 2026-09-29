import logging
from contextlib import contextmanager
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

from config.database import banco
from flask import Blueprint, jsonify, request
from routes.usuario import obter_usuario_id

tratamento = Blueprint("tratamento", __name__)
logger = logging.getLogger(__name__)

STATUS_PERMITIDOS = {"ativo", "pausado", "concluido", "cancelado"}
UNIDADES_DOSAGEM_PERMITIDAS = {"mg", "mcg", "g", "ml", "ui", "gota"}
FORMAS_CONSUMO_PERMITIDAS = {
    "oral",
    "sublingual",
    "topica",
    "injetavel",
    "inalatoria",
    "oftalmica",
    "nasal",
    "retal",
    "vaginal",
    "outra",
}
LIMITE_PAGINA = 100
LIMITE_DURACAO_DIAS = 3650


@contextmanager
def sessao_banco():
    """Confirma a transação no sucesso e sempre libera os recursos."""
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
                # Não encobre o erro original se a conexão já estiver indisponível.
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
    dados = request.get_json(silent=True)
    return dados if isinstance(dados, dict) else {}


def texto(dados, campo):
    valor = dados.get(campo)
    return valor.strip() if isinstance(valor, str) else ""


def decimal_positivo(valor, campo):
    if isinstance(valor, bool) or valor is None:
        return None, f"{campo} deve ser maior que zero!"

    try:
        valor_decimal = Decimal(str(valor))
    except (InvalidOperation, ValueError):
        return None, f"{campo} deve ser um número válido!"

    if not valor_decimal.is_finite() or valor_decimal <= 0:
        return None, f"{campo} deve ser maior que zero!"

    return valor_decimal, None


def inteiro_positivo(valor, campo, limite):
    if isinstance(valor, bool) or valor is None:
        return None, f"{campo} deve ser um número inteiro positivo!"

    try:
        inteiro = int(str(valor))
    except (TypeError, ValueError):
        return None, f"{campo} deve ser um número inteiro positivo!"

    if str(inteiro) != str(valor).strip() or not 0 < inteiro <= limite:
        return None, f"{campo} deve estar entre 1 e {limite}!"

    return inteiro, None


def normalizar_opcao(valor, permitidos, campo):
    opcao = texto({"valor": valor}, "valor").lower()
    if opcao not in permitidos:
        opcoes = ", ".join(sorted(permitidos))
        return None, f"{campo} inválida. Valores aceitos: {opcoes}."
    return opcao, None


def validar_tratamento(dados):
    medicamento = texto(dados, "medicamento")
    if not medicamento:
        return None, "Medicamento é obrigatório!"
    if len(medicamento) > 150:
        return None, "Medicamento deve ter no máximo 150 caracteres!"

    dosagem_valor, erro = decimal_positivo(dados.get("dosagem_valor"), "Dosagem")
    if erro:
        return None, erro

    quantidade_por_dose, erro = decimal_positivo(
        dados.get("quantidade_por_dose"), "Quantidade por dose"
    )
    if erro:
        return None, erro

    dosagem_unidade, erro = normalizar_opcao(
        dados.get("dosagem_unidade"), UNIDADES_DOSAGEM_PERMITIDAS, "Unidade de dosagem"
    )
    if erro:
        return None, erro

    forma_consumo, erro = normalizar_opcao(
        dados.get("forma_consumo"), FORMAS_CONSUMO_PERMITIDAS, "Forma de consumo"
    )
    if erro:
        return None, erro

    data_inicio_texto = texto(dados, "data_inicio")
    try:
        data_inicio = date.fromisoformat(data_inicio_texto)
    except ValueError:
        return None, "Data de início deve estar no formato AAAA-MM-DD!"

    duracao_dias, erro = inteiro_positivo(
        dados.get("duracao_dias"), "Duração em dias", LIMITE_DURACAO_DIAS
    )
    if erro:
        return None, erro

    return {
        "medicamento": medicamento,
        "dosagem_valor": dosagem_valor,
        "dosagem_unidade": dosagem_unidade,
        "quantidade_por_dose": quantidade_por_dose,
        "forma_consumo": forma_consumo,
        "data_inicio": data_inicio,
        "duracao_dias": duracao_dias,
    }, None


def serializar_valor(valor):
    if isinstance(valor, (date, datetime)):
        return valor.isoformat()
    if isinstance(valor, Decimal):
        return str(valor)
    return valor


def serializar_tratamento(registro):
    return {chave: serializar_valor(valor) for chave, valor in registro.items()}


def resposta_erro_banco():
    return jsonify({"erro": "Não foi possível processar o tratamento!"}), 500


def buscar_tratamento_do_usuario(cursor, tratamento_id, usuario_id, bloquear=False):
    bloqueio = " FOR UPDATE" if bloquear else ""
    cursor.execute(
        f"""
        SELECT
            id,
            medicamento,
            dosagem_valor,
            dosagem_unidade,
            quantidade_por_dose,
            forma_consumo,
            data_inicio,
            duracao_dias,
            status,
            criado_em
        FROM tratamentos
        WHERE id = %s AND usuario_id = %s{bloqueio}
        """,
        (tratamento_id, usuario_id),
    )
    return cursor.fetchone()


def usuario_autenticado():
    usuario_id = obter_usuario_id()
    if usuario_id is None:
        return None, (jsonify({"erro": "Token inválido ou não informado!"}), 401)
    return usuario_id, None


@tratamento.route("/tratamentos", methods=["POST"])
def cadastrar_tratamento():
    usuario_id, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    dados = dados_json()
    if not dados:
        return jsonify({"erro": "Dados do tratamento são obrigatórios!"}), 400

    tratamento_validado, erro_validacao = validar_tratamento(dados)
    if erro_validacao:
        return jsonify({"erro": erro_validacao}), 400

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                """
                INSERT INTO tratamentos (
                    usuario_id,
                    medicamento,
                    dosagem_valor,
                    dosagem_unidade,
                    quantidade_por_dose,
                    forma_consumo,
                    data_inicio,
                    duracao_dias,
                    status
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'ativo')
                """,
                (
                    usuario_id,
                    tratamento_validado["medicamento"],
                    tratamento_validado["dosagem_valor"],
                    tratamento_validado["dosagem_unidade"],
                    tratamento_validado["quantidade_por_dose"],
                    tratamento_validado["forma_consumo"],
                    tratamento_validado["data_inicio"],
                    tratamento_validado["duracao_dias"],
                ),
            )
            tratamento_id = cursor.lastrowid
    except Exception:
        logger.exception("Erro ao cadastrar tratamento")
        return resposta_erro_banco()

    return jsonify(
        {
            "mensagem": "Tratamento cadastrado com sucesso!",
            "tratamento_id": tratamento_id,
        }
    ), 201


@tratamento.route("/tratamentos", methods=["GET"])
def listar_tratamentos():
    usuario_id, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        limite, erro_limite = inteiro_positivo(
            request.args.get("limit", 50), "Limit", LIMITE_PAGINA
        )
        if erro_limite:
            return jsonify({"erro": erro_limite}), 400

        offset = int(request.args.get("offset", 0))
        if offset < 0:
            return jsonify({"erro": "Offset não pode ser negativo!"}), 400
    except (TypeError, ValueError):
        return jsonify({"erro": "Parâmetros de paginação inválidos!"}), 400

    status = request.args.get("status")
    if status is not None:
        status, erro_status = normalizar_opcao(status, STATUS_PERMITIDOS, "Status")
        if erro_status:
            return jsonify({"erro": erro_status}), 400

    try:
        with sessao_banco() as (_, cursor):
            sql = """
                SELECT
                    id,
                    medicamento,
                    dosagem_valor,
                    dosagem_unidade,
                    quantidade_por_dose,
                    forma_consumo,
                    data_inicio,
                    duracao_dias,
                    status,
                    criado_em
                FROM tratamentos
                WHERE usuario_id = %s
            """
            parametros = [usuario_id]
            if status:
                sql += " AND status = %s"
                parametros.append(status)
            sql += " ORDER BY criado_em DESC, id DESC LIMIT %s OFFSET %s"
            parametros.extend([limite, offset])
            cursor.execute(sql, tuple(parametros))
            tratamentos = cursor.fetchall()
    except Exception:
        logger.exception("Erro ao listar tratamentos")
        return resposta_erro_banco()

    return jsonify(
        {
            "tratamentos": [serializar_tratamento(item) for item in tratamentos],
            "paginacao": {"limit": limite, "offset": offset},
        }
    ), 200


@tratamento.route("/tratamentos/<int:tratamento_id>", methods=["GET"])
def buscar_tratamento(tratamento_id):
    usuario_id, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            tratamento_encontrado = buscar_tratamento_do_usuario(
                cursor, tratamento_id, usuario_id
            )
    except Exception:
        logger.exception("Erro ao buscar tratamento")
        return resposta_erro_banco()

    if not tratamento_encontrado:
        return jsonify({"erro": "Tratamento não encontrado!"}), 404

    return jsonify(serializar_tratamento(tratamento_encontrado)), 200


@tratamento.route("/tratamentos/<int:tratamento_id>", methods=["PUT"])
def editar_tratamento(tratamento_id):
    usuario_id, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    dados = dados_json()
    if not dados:
        return jsonify({"erro": "Dados do tratamento são obrigatórios!"}), 400

    tratamento_validado, erro_validacao = validar_tratamento(dados)
    if erro_validacao:
        return jsonify({"erro": erro_validacao}), 400

    try:
        with sessao_banco() as (_, cursor):
            existente = buscar_tratamento_do_usuario(
                cursor, tratamento_id, usuario_id, bloquear=True
            )
            if not existente:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404
            if existente["status"] == "cancelado":
                return jsonify({"erro": "Tratamento cancelado não pode ser editado!"}), 409

            cursor.execute(
                """
                UPDATE tratamentos
                SET
                    medicamento = %s,
                    dosagem_valor = %s,
                    dosagem_unidade = %s,
                    quantidade_por_dose = %s,
                    forma_consumo = %s,
                    data_inicio = %s,
                    duracao_dias = %s
                WHERE id = %s AND usuario_id = %s
                """,
                (
                    tratamento_validado["medicamento"],
                    tratamento_validado["dosagem_valor"],
                    tratamento_validado["dosagem_unidade"],
                    tratamento_validado["quantidade_por_dose"],
                    tratamento_validado["forma_consumo"],
                    tratamento_validado["data_inicio"],
                    tratamento_validado["duracao_dias"],
                    tratamento_id,
                    usuario_id,
                ),
            )
    except Exception:
        logger.exception("Erro ao editar tratamento")
        return resposta_erro_banco()

    return jsonify({"mensagem": "Tratamento atualizado com sucesso!"}), 200


@tratamento.route("/tratamentos/<int:tratamento_id>/status", methods=["PATCH"])
def alterar_status_tratamento(tratamento_id):
    usuario_id, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    novo_status, erro_status = normalizar_opcao(
        dados_json().get("status"), STATUS_PERMITIDOS, "Status"
    )
    if erro_status:
        return jsonify({"erro": erro_status}), 400

    try:
        with sessao_banco() as (_, cursor):
            existente = buscar_tratamento_do_usuario(
                cursor, tratamento_id, usuario_id, bloquear=True
            )
            if not existente:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404

            cursor.execute(
                "UPDATE tratamentos SET status = %s WHERE id = %s AND usuario_id = %s",
                (novo_status, tratamento_id, usuario_id),
            )
    except Exception:
        logger.exception("Erro ao alterar status do tratamento")
        return resposta_erro_banco()

    return jsonify({"mensagem": "Status do tratamento atualizado com sucesso!"}), 200


@tratamento.route("/tratamentos/<int:tratamento_id>", methods=["DELETE"])
def excluir_tratamento(tratamento_id):
    """Preserva o histórico ao cancelar, em vez de apagar o tratamento."""
    usuario_id, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            existente = buscar_tratamento_do_usuario(
                cursor, tratamento_id, usuario_id, bloquear=True
            )
            if not existente:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404

            if existente["status"] != "cancelado":
                cursor.execute(
                    "UPDATE tratamentos SET status = 'cancelado' WHERE id = %s AND usuario_id = %s",
                    (tratamento_id, usuario_id),
                )
    except Exception:
        logger.exception("Erro ao cancelar tratamento")
        return resposta_erro_banco()

    return jsonify({"mensagem": "Tratamento cancelado com sucesso!"}), 200
