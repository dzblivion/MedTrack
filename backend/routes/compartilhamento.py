import hashlib
import hmac
import logging
import os
import secrets
from contextlib import contextmanager
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from config.database import banco
from flask import Blueprint, jsonify, request
from routes.usuario import obter_usuario_id

compartilhamento = Blueprint('compartilhamento', __name__)
logger = logging.getLogger(__name__)

FUSO_HORARIO = ZoneInfo("America/Fortaleza")
VALIDADE_CODIGO_HORAS = 24

@contextmanager
def sessao_banco():
    """Confirma a transação no sucesso e libera conexão e cursor."""
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

def agora_local():
    """Retorna horário local sem tzinfo, compatível com a coluna DATETIME."""
    return datetime.now(FUSO_HORARIO).replace(tzinfo=None)

def obter_dados_json():
    dados = request.get_json(silent=True)
    return dados if isinstance(dados, dict) else {}

def obter_usuario_autenticado():
    usuario_id = obter_usuario_id()
    if usuario_id is None:
        return None, (jsonify({"erro": "Token inválido ou não informado!"}), 401)
    return usuario_id, None

def usuario_e_profissional(cursor, usuario_id):
    cursor.execute(
        "SELECT 1 FROM profissionais WHERE usuario_id = %s LIMIT 1",
        (usuario_id,),
    )
    return cursor.fetchone() is not None

def exigir_paciente(cursor, usuario_id):
    """As operações de gestão dos compartilhamentos são exclusivas do paciente."""
    if usuario_e_profissional(cursor, usuario_id):
        return jsonify({"erro": "Esta operação está disponível apenas para pacientes!"}), 403
    return None

def segredo_compartilhamento():
    segredo = (
        os.getenv("COMPARTILHAMENTO_CODIGO_SECRET")
        or os.getenv("JWT_SECRET")
    )
    if not segredo:
        raise RuntimeError(
            "COMPARTILHAMENTO_CODIGO_SECRET ou JWT_SECRET não configurado"
        )
    return segredo

def gerar_codigo_compartilhamento():
    # 128 bits aleatórios; o código é mostrado ao paciente somente na criação.
    return secrets.token_urlsafe(16)

def hash_codigo_compartilhamento(codigo):
    mensagem = f"compartilhamento-tratamento:{codigo}".encode()
    return hmac.new(
        segredo_compartilhamento().encode("utf-8"),
        mensagem,
        hashlib.sha256,
    ).hexdigest()

def serializar_valor(valor):
    if isinstance(valor, (date, datetime)):
        return valor.isoformat()
    if hasattr(valor, "as_tuple"):  # decimal.Decimal
        return str(valor)
    return valor

def serializar_registro(registro):
    return {chave: serializar_valor(valor) for chave, valor in registro.items()}

def carregar_frequencias(cursor, tratamento_id):
    cursor.execute(
        """
        SELECT id, tipo, intervalo_valor, ancora_em, fuso_horario, ativo
        FROM regras_frequencia
        WHERE tratamento_id = %s
        ORDER BY id
        """,
        (tratamento_id,),
    )
    regras = cursor.fetchall()
    frequencias = []

    for regra in regras:
        regra_id = regra["id"]
        cursor.execute(
            """
            SELECT horario
            FROM horarios_frequencia
            WHERE regra_frequencia_id = %s
            ORDER BY horario
            """,
            (regra_id,),
        )
        horarios = [str(item["horario"]) for item in cursor.fetchall()]

        cursor.execute(
            """
            SELECT dia_semana
            FROM dias_semana_frequencia
            WHERE regra_frequencia_id = %s
            ORDER BY dia_semana
            """,
            (regra_id,),
        )
        dias_semana = [item["dia_semana"] for item in cursor.fetchall()]

        frequencias.append({
            "id": regra_id,
            "tipo": regra["tipo"],
            "intervalo_valor": regra["intervalo_valor"],
            "ancora_em": serializar_valor(regra["ancora_em"]),
            "fuso_horario": regra["fuso_horario"],
            "ativo": regra["ativo"],
            "horarios": horarios,
            "dias_semana": dias_semana,
        })

    return frequencias

def compartilhar_nao_encontrado():
    return jsonify({"erro": "Compartilhamento não encontrado!"}), 404

@compartilhamento.route("/compartilhamentos", methods=["POST"])
def criar_compartilhamento():
    paciente_id, erro_autenticacao = obter_usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    dados = obter_dados_json()
    tratamento_id_bruto = dados.get("tratamento_id")
    if isinstance(tratamento_id_bruto, bool):
        return jsonify({"erro": "Informe um tratamento_id válido!"}), 400
    try:
        tratamento_id = int(tratamento_id_bruto)
    except (TypeError, ValueError):
        return jsonify({"erro": "Informe um tratamento_id válido!"}), 400
    if tratamento_id <= 0 or str(tratamento_id) != str(tratamento_id_bruto).strip():
        return jsonify({"erro": "Informe um tratamento_id válido!"}), 400

    codigo = gerar_codigo_compartilhamento()
    codigo_hash = hash_codigo_compartilhamento(codigo)
    criado_em = agora_local()
    expira_em = criado_em + timedelta(hours=VALIDADE_CODIGO_HORAS)

    try:
        with sessao_banco() as (_, cursor):
            erro_paciente = exigir_paciente(cursor, paciente_id)
            if erro_paciente:
                return erro_paciente

            cursor.execute(
                """
                SELECT id, status
                FROM tratamentos
                WHERE id = %s AND usuario_id = %s
                FOR UPDATE
                """,
                (tratamento_id, paciente_id),
            )
            tratamento = cursor.fetchone()
            if not tratamento:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404
            if tratamento["status"] == "cancelado":
                return jsonify({"erro": "Não é possível compartilhar um tratamento cancelado!"}), 409

            cursor.execute(
                """
                INSERT INTO compartilhamentos (
                    tratamento_id,
                    paciente_usuario_id,
                    codigo_hash,
                    status,
                    criado_em,
                    expira_em
                )
                VALUES (%s, %s, %s, 'pendente', %s, %s)
                """,
                (tratamento_id, paciente_id, codigo_hash, criado_em, expira_em),
            )
            compartilhamento_id = cursor.lastrowid
    except Exception:
        logger.exception("Erro ao criar compartilhamento de tratamento")
        return jsonify({"erro": "Não foi possível criar o compartilhamento!"}), 500

    return jsonify({
        "mensagem": "Código de compartilhamento criado com sucesso!",
        "compartilhamento_id": compartilhamento_id,
        "codigo": codigo,
        "expira_em": expira_em.isoformat(),
        "validade_horas": VALIDADE_CODIGO_HORAS,
        "aviso": "Guarde este código. Ele será exibido apenas nesta resposta.",
    }), 201

@compartilhamento.route("/compartilhamentos", methods=["GET"])
def listar_compartilhamentos_paciente():
    paciente_id, erro_autenticacao = obter_usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            erro_paciente = exigir_paciente(cursor, paciente_id)
            if erro_paciente:
                return erro_paciente

            agora = agora_local()
            cursor.execute(
                """
                UPDATE compartilhamentos
                SET status = 'expirado'
                WHERE paciente_usuario_id = %s
                  AND status = 'pendente'
                  AND expira_em <= %s
                """,
                (paciente_id, agora),
            )
            cursor.execute(
                """
                SELECT
                    c.id,
                    c.tratamento_id,
                    t.medicamento,
                    c.profissional_usuario_id,
                    u.nome AS profissional_nome,
                    p.profissao,
                    p.registro,
                    p.uf_registro,
                    c.status,
                    c.criado_em,
                    c.expira_em,
                    c.utilizado_em,
                    c.revogado_em
                FROM compartilhamentos c
                INNER JOIN tratamentos t ON t.id = c.tratamento_id
                LEFT JOIN usuarios u ON u.id = c.profissional_usuario_id
                LEFT JOIN profissionais p ON p.usuario_id = c.profissional_usuario_id
                WHERE c.paciente_usuario_id = %s
                ORDER BY c.criado_em DESC, c.id DESC
                """,
                (paciente_id,),
            )
            registros = cursor.fetchall()
    except Exception:
        logger.exception("Erro ao listar compartilhamentos do paciente")
        return jsonify({"erro": "Não foi possível listar os compartilhamentos!"}), 500

    return jsonify({"compartilhamentos": [serializar_registro(item) for item in registros]}), 200

@compartilhamento.route("/compartilhamentos/validar", methods=["POST"])
def validar_codigo_compartilhamento():
    profissional_id, erro_autenticacao = obter_usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    codigo = obter_dados_json().get("codigo")
    if not isinstance(codigo, str) or not codigo.strip():
        return jsonify({"erro": "Informe o código de compartilhamento!"}), 400
    codigo = codigo.strip()

    try:
        codigo_hash = hash_codigo_compartilhamento(codigo)
        agora = agora_local()
        with sessao_banco() as (_, cursor):
            if not usuario_e_profissional(cursor, profissional_id):
                return jsonify({"erro": "Apenas profissionais cadastrados podem validar códigos!"}), 403

            # O bloqueio evita que duas requisições resgatem o mesmo código.
            cursor.execute(
                """
                SELECT
                    id,
                    tratamento_id,
                    paciente_usuario_id,
                    status,
                    expira_em
                FROM compartilhamentos
                WHERE codigo_hash = %s
                FOR UPDATE
                """,
                (codigo_hash,),
            )
            registro = cursor.fetchone()
            if not registro:
                return jsonify({"erro": "Código inválido ou indisponível!"}), 400
            if registro["status"] != "pendente":
                return jsonify({"erro": "Este código já foi utilizado ou não está disponível!"}), 409
            if registro["expira_em"] <= agora:
                cursor.execute(
                    "UPDATE compartilhamentos SET status = 'expirado' WHERE id = %s",
                    (registro["id"],),
                )
                return jsonify({"erro": "Código expirado! Solicite um novo código ao paciente."}), 400

            cursor.execute(
                """
                UPDATE compartilhamentos
                SET status = 'ativo',
                    profissional_usuario_id = %s,
                    utilizado_em = %s
                WHERE id = %s AND status = 'pendente'
                """,
                (profissional_id, agora, registro["id"]),
            )
            cursor.execute(
                """
                SELECT medicamento, dosagem_valor, dosagem_unidade,
                       quantidade_por_dose, forma_consumo, data_inicio,
                       duracao_dias, status
                FROM tratamentos
                WHERE id = %s
                """,
                (registro["tratamento_id"],),
            )
            tratamento = cursor.fetchone()
    except Exception:
        logger.exception("Erro ao validar código de compartilhamento")
        return jsonify({"erro": "Não foi possível validar o código!"}), 500

    return jsonify({
        "mensagem": "Código validado. O tratamento foi compartilhado com você.",
        "compartilhamento_id": registro["id"],
        "tratamento": serializar_registro(tratamento),
    }), 200

@compartilhamento.route("/compartilhamentos/profissional", methods=["GET"])
def listar_compartilhamentos_profissional():
    profissional_id, erro_autenticacao = obter_usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            if not usuario_e_profissional(cursor, profissional_id):
                return jsonify({"erro": "Apenas profissionais cadastrados podem consultar esta lista!"}), 403

            cursor.execute(
                """
                SELECT
                    c.id AS compartilhamento_id,
                    c.criado_em AS compartilhado_em,
                    c.utilizado_em,
                    t.id AS tratamento_id,
                    t.usuario_id AS paciente_usuario_id,
                    u.nome AS paciente_nome,
                    t.medicamento,
                    t.dosagem_valor,
                    t.dosagem_unidade,
                    t.quantidade_por_dose,
                    t.forma_consumo,
                    t.data_inicio,
                    t.duracao_dias,
                    t.status AS tratamento_status
                FROM compartilhamentos c
                INNER JOIN tratamentos t ON t.id = c.tratamento_id
                INNER JOIN usuarios u ON u.id = c.paciente_usuario_id
                WHERE c.profissional_usuario_id = %s
                  AND c.status = 'ativo'
                ORDER BY c.utilizado_em DESC, c.id DESC
                """,
                (profissional_id,),
            )
            registros = cursor.fetchall()
    except Exception:
        logger.exception("Erro ao listar tratamentos compartilhados com profissional")
        return jsonify({"erro": "Não foi possível listar os tratamentos compartilhados!"}), 500

    return jsonify({"compartilhamentos": [serializar_registro(item) for item in registros]}), 200

@compartilhamento.route("/compartilhamentos/<int:compartilhamento_id>", methods=["GET"])
def buscar_compartilhamento(compartilhamento_id):
    usuario_id, erro_autenticacao = obter_usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            profissional = usuario_e_profissional(cursor, usuario_id)
            cursor.execute(
                """
                SELECT
                    c.id,
                    c.paciente_usuario_id,
                    c.profissional_usuario_id,
                    c.status AS compartilhamento_status,
                    c.criado_em AS compartilhado_em,
                    c.expira_em,
                    c.utilizado_em,
                    c.revogado_em,
                    t.id AS tratamento_id,
                    t.usuario_id AS dono_tratamento_id,
                    t.medicamento,
                    t.dosagem_valor,
                    t.dosagem_unidade,
                    t.quantidade_por_dose,
                    t.forma_consumo,
                    t.data_inicio,
                    t.duracao_dias,
                    t.status AS tratamento_status,
                    t.criado_em AS tratamento_criado_em,
                    u.nome AS paciente_nome
                FROM compartilhamentos c
                INNER JOIN tratamentos t ON t.id = c.tratamento_id
                INNER JOIN usuarios u ON u.id = c.paciente_usuario_id
                WHERE c.id = %s
                """,
                (compartilhamento_id,),
            )
            registro = cursor.fetchone()
            if not registro:
                return compartilhar_nao_encontrado()

            if profissional:
                # A permissão é reconsultada em toda chamada; revogação bloqueia na hora.
                autorizado = (
                    registro["profissional_usuario_id"] == usuario_id
                    and registro["compartilhamento_status"] == "ativo"
                )
            else:
                autorizado = registro["paciente_usuario_id"] == usuario_id

            if not autorizado:
                return compartilhar_nao_encontrado()

            tratamento_id = registro["tratamento_id"]
            frequencias = carregar_frequencias(cursor, tratamento_id)

            cursor.execute(
                """
                SELECT id, agendada_para, status, registrada_em
                FROM doses
                WHERE tratamento_id = %s
                ORDER BY agendada_para DESC, id DESC
                """,
                (tratamento_id,),
            )
            doses = [serializar_registro(item) for item in cursor.fetchall()]
    except Exception:
        logger.exception("Erro ao consultar compartilhamento")
        return jsonify({"erro": "Não foi possível consultar o compartilhamento!"}), 500

    campos_compartilhamento = {
        "id": registro["id"],
        "status": registro["compartilhamento_status"],
        "compartilhado_em": serializar_valor(registro["compartilhado_em"]),
        "expira_em": serializar_valor(registro["expira_em"]),
        "utilizado_em": serializar_valor(registro["utilizado_em"]),
        "revogado_em": serializar_valor(registro["revogado_em"]),
    }
    dados_tratamento = {
        "id": registro["tratamento_id"],
        "paciente_usuario_id": registro["dono_tratamento_id"],
        "paciente_nome": registro["paciente_nome"],
        "medicamento": registro["medicamento"],
        "dosagem_valor": serializar_valor(registro["dosagem_valor"]),
        "dosagem_unidade": registro["dosagem_unidade"],
        "quantidade_por_dose": serializar_valor(registro["quantidade_por_dose"]),
        "forma_consumo": registro["forma_consumo"],
        "data_inicio": serializar_valor(registro["data_inicio"]),
        "duracao_dias": registro["duracao_dias"],
        "status": registro["tratamento_status"],
        "criado_em": serializar_valor(registro["tratamento_criado_em"]),
        "frequencias": frequencias,
        "doses": doses,
    }
    return jsonify({
        "compartilhamento": campos_compartilhamento,
        "tratamento": dados_tratamento,
    }), 200

@compartilhamento.route("/compartilhamentos/<int:compartilhamento_id>", methods=["DELETE"])
def revogar_compartilhamento(compartilhamento_id):
    paciente_id, erro_autenticacao = obter_usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            erro_paciente = exigir_paciente(cursor, paciente_id)
            if erro_paciente:
                return erro_paciente

            cursor.execute(
                """
                SELECT id, status
                FROM compartilhamentos
                WHERE id = %s AND paciente_usuario_id = %s
                FOR UPDATE
                """,
                (compartilhamento_id, paciente_id),
            )
            registro = cursor.fetchone()
            if not registro:
                return compartilhar_nao_encontrado()

            if registro["status"] == "revogado":
                return jsonify({"mensagem": "O compartilhamento já estava revogado!"}), 200
            if registro["status"] == "expirado":
                return jsonify({"erro": "Não é possível revogar um código já expirado!"}), 409

            cursor.execute(
                """
                UPDATE compartilhamentos
                SET status = 'revogado', revogado_em = %s
                WHERE id = %s AND paciente_usuario_id = %s
                """,
                (agora_local(), compartilhamento_id, paciente_id),
            )
    except Exception:
        logger.exception("Erro ao revogar compartilhamento")
        return jsonify({"erro": "Não foi possível revogar o compartilhamento!"}), 500

    return jsonify({"mensagem": "Compartilhamento revogado com sucesso!"}), 200