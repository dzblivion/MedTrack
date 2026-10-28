import logging
import os
import tempfile
import unicodedata
from contextlib import contextmanager
from datetime import date, datetime, timedelta
from datetime import time as horario_time
from decimal import Decimal, InvalidOperation
from math import ceil
from zoneinfo import ZoneInfo

from config.database import banco
from flask import Blueprint, jsonify, request
from routes.usuario import obter_usuario_id
from services.prescricao_service import processar_prescricao

tratamento = Blueprint("tratamento", __name__)
logger = logging.getLogger(__name__)

FUSO_HORARIO = ZoneInfo("America/Fortaleza")
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
LIMITE_INTERVALO_HORAS = 24 * LIMITE_DURACAO_DIAS
LIMITE_DOSES_GERADAS = 10_000
TIPOS_FREQUENCIA = {"diario", "semanal", "intervalo_horas", "intervalo_dias"}


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

def normalizar_forma_consumo(valor):
    if not isinstance(valor, str) or not valor.strip():
        return None

    # Remove acentos e padroniza letras e espaços.
    texto = unicodedata.normalize("NFKD", valor.strip().lower())
    texto = "".join(
        caractere
        for caractere in texto
        if not unicodedata.combining(caractere)
    )
    texto = " ".join(texto.split())

    equivalencias = {
        "oral": "oral",
        "uso oral": "oral",
        "via oral": "oral",
        "sublingual": "sublingual",
        "topica": "topica",
        "uso topico": "topica",
        "via topica": "topica",
        "uso externo": "topica",
        "injetavel": "injetavel",
        "inalatoria": "inalatoria",
        "oftalmica": "oftalmica",
        "nasal": "nasal",
        "retal": "retal",
        "vaginal": "vaginal",
        "outra": "outra",
    }

    return equivalencias.get(texto)

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

    dosagem_bruta = dados.get("dosagem_valor")
    unidade_bruta = dados.get("dosagem_unidade")

    
    if dosagem_bruta is None and unidade_bruta not in (None, ""):
        return None, "Informe o valor da dosagem junto com a unidade!"


    if dosagem_bruta in (None, ""):
        dosagem_valor = None
        dosagem_unidade = None
    else:
        dosagem_valor, erro = decimal_positivo(
            dosagem_bruta, "Valor da dosagem"
        )
        if erro:
            return None, erro

        dosagem_unidade, erro = normalizar_opcao(
            unidade_bruta, UNIDADES_DOSAGEM_PERMITIDAS, "Unidade de dosagem"
        )
        if erro:
            return None, erro

    quantidade_por_dose, erro = decimal_positivo(
        dados.get("quantidade_por_dose"), "Quantidade por dose"
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
    except (ValueError, TypeError):
        return None, "Data de início deve estar no formato AAAA-MM-DD!"

    duracao_bruta = dados.get("duracao_dias")

    if duracao_bruta in (None, ""):
        duracao_dias = None
    else:
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


def validar_ancora_em(valor, data_inicio):
    if not isinstance(valor, str) or not valor.strip():
        return None, "O campo ancora_em é obrigatório!"

    texto_ancora = valor.strip()
    if texto_ancora.endswith("Z"):
        texto_ancora = f"{texto_ancora[:-1]}+00:00"

    try:
        ancora_em = datetime.fromisoformat(texto_ancora)
    except ValueError:
        return None, "O campo ancora_em deve estar no formato ISO 8601!"

    if ancora_em.tzinfo is None or ancora_em.utcoffset() is None:
        return None, "O campo ancora_em deve informar o fuso horário!"

    # MySQL DATETIME não armazena offset. Normalizamos para o fuso registrado na regra.
    ancora_local = ancora_em.astimezone(FUSO_HORARIO).replace(tzinfo=None)
    if ancora_local.date() != data_inicio:
        return None, "A data de ancora_em deve ser igual à data de início!"

    return ancora_local, None


def validar_horarios(valor):
    if not isinstance(valor, list) or not valor:
        return None, "Informe pelo menos um horário!"

    horarios = []
    vistos = set()
    for item in valor:
        if not isinstance(item, str):
            return None, "Cada horário deve estar no formato HH:MM!"

        try:
            horario = horario_time.fromisoformat(item.strip())
        except ValueError:
            return None, "Cada horário deve estar no formato HH:MM!"

        if horario.tzinfo is not None:
            return None, "Horários não devem informar fuso horário!"

        horario = horario.replace(microsecond=0)
        if horario in vistos:
            return None, "Os horários não podem se repetir!"

        vistos.add(horario)
        horarios.append(horario.strftime("%H:%M:%S"))

    return horarios, None


def validar_dias_semana(valor):
    if not isinstance(valor, list) or not valor:
        return None, "Informe pelo menos um dia da semana!"

    dias_semana = []
    vistos = set()
    for dia in valor:
        if isinstance(dia, bool) or not isinstance(dia, int) or not 1 <= dia <= 7:
            return None, "Cada dia da semana deve ser um inteiro entre 1 e 7!"
        if dia in vistos:
            return None, "Os dias da semana não podem se repetir!"

        vistos.add(dia)
        dias_semana.append(dia)

    return dias_semana, None


def validar_frequencia(dados, data_inicio, duracao_dias):
    frequencia = dados.get("frequencia")
    if not isinstance(frequencia, dict):
        return None, "Dados da frequência são obrigatórios!"

    tipo = texto(frequencia, "tipo").lower()
    if tipo not in TIPOS_FREQUENCIA:
        return None, "Tipo de frequência inválido!"

    ancora_em, erro = validar_ancora_em(frequencia.get("ancora_em"), data_inicio)
    if erro:
        return None, erro

    horarios_brutos = frequencia.get("horarios", [])
    dias_brutos = frequencia.get("dias_semana", [])
    intervalo_bruto = frequencia.get("intervalo_valor")

    if tipo in {"diario", "semanal"}:
        horarios, erro = validar_horarios(horarios_brutos)
        if erro:
            return None, erro
    else:
        if horarios_brutos not in (None, []):
            return None, "Horários só podem ser informados para frequência diária ou semanal!"
        horarios = []

    if tipo == "semanal":
        dias_semana, erro = validar_dias_semana(dias_brutos)
        if erro:
            return None, erro
    else:
        if dias_brutos not in (None, []):
            return None, "Dias da semana só podem ser informados para frequência semanal!"
        dias_semana = []

    if tipo == "intervalo_horas":
        intervalo_valor, erro = inteiro_positivo(
            intervalo_bruto, "intervalo_valor", LIMITE_INTERVALO_HORAS
        )
        if erro:
            return None, erro
    elif tipo == "intervalo_dias":
        intervalo_valor, erro = inteiro_positivo(
            intervalo_bruto, "intervalo_valor", LIMITE_DURACAO_DIAS
        )
        if erro:
            return None, erro
    else:
        if intervalo_bruto is not None:
            return None, "intervalo_valor só pode ser informado para frequências por intervalo!"
        intervalo_valor = None

    return {
        "tipo": tipo,
        "ancora_em": ancora_em,
        "horarios": horarios,
        "dias_semana": dias_semana,
        "intervalo_valor": intervalo_valor,
        "duracao_dias": duracao_dias,
    }, None


def gerar_doses(frequencia):
    tipo = frequencia["tipo"]
    ancora_em = frequencia["ancora_em"]
    duracao_dias = frequencia["duracao_dias"]

    if duracao_dias is None:
        return [], None

    horarios = frequencia["horarios"]
    dias_semana = frequencia["dias_semana"]
    intervalo_valor = frequencia["intervalo_valor"]

    if tipo == "diario":
        quantidade_prevista = duracao_dias * len(horarios)
    elif tipo == "semanal":
        quantidade_dias = sum(
            1
            for deslocamento in range(duracao_dias)
            if (ancora_em.date() + timedelta(days=deslocamento)).isoweekday()
            in dias_semana
        )
        quantidade_prevista = quantidade_dias * len(horarios)
    elif tipo == "intervalo_horas":
        quantidade_prevista = ceil((duracao_dias * 24) / intervalo_valor)
    else:
        quantidade_prevista = ceil(duracao_dias / intervalo_valor)

    if quantidade_prevista > LIMITE_DOSES_GERADAS:
        return None, (
            f"A frequência gera mais de {LIMITE_DOSES_GERADAS} doses; "
            "reduza a duração ou aumente o intervalo!"
        )

    doses = []
    if tipo == "diario":
        data_atual = ancora_em.date()

        for _ in range(duracao_dias):
            for horario in horarios:
                dose = datetime.combine(
                    data_atual,
                    horario_time.fromisoformat(horario)
                )

                # Só agenda doses a partir da âncora.
                if dose >= ancora_em:
                    doses.append(dose)

            data_atual += timedelta(days=1)
    elif tipo == "semanal":
        data_atual = ancora_em.date()

        for _ in range(duracao_dias):
            if data_atual.isoweekday() in dias_semana:
                for horario in horarios:
                    dose = datetime.combine(
                        data_atual,
                        horario_time.fromisoformat(horario)
                    )

                    # Evita doses anteriores à âncora.
                    if dose >= ancora_em:
                        doses.append(dose)

            data_atual += timedelta(days=1)
    else:
        incremento = (
            timedelta(hours=intervalo_valor)
            if tipo == "intervalo_horas"
            else timedelta(days=intervalo_valor)
        )
        data_hora_atual = ancora_em
        data_final = ancora_em + timedelta(days=duracao_dias)
        while data_hora_atual < data_final:
            doses.append(data_hora_atual)
            data_hora_atual += incremento

    if not doses:
        return None, "A frequência informada não gera doses durante o tratamento!"

    return doses, None


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

    frequencia_validada, erro_frequencia = validar_frequencia(
        dados,
        tratamento_validado["data_inicio"],
        tratamento_validado["duracao_dias"],
    )
    if erro_frequencia:
        return jsonify({"erro": erro_frequencia}), 400

    doses, erro_doses = gerar_doses(frequencia_validada)
    if erro_doses:
        return jsonify({"erro": erro_doses}), 400

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

            cursor.execute(
                """
                INSERT INTO regras_frequencia (
                    tratamento_id,
                    tipo,
                    intervalo_valor,
                    ancora_em,
                    fuso_horario
                )
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    tratamento_id,
                    frequencia_validada["tipo"],
                    frequencia_validada["intervalo_valor"],
                    frequencia_validada["ancora_em"],
                    FUSO_HORARIO.key,
                ),
            )

            regra_frequencia_id = cursor.lastrowid

            for horario in frequencia_validada["horarios"]:
                cursor.execute(
                    """
                    INSERT INTO horarios_frequencia (
                        regra_frequencia_id,
                        horario
                    )
                    VALUES (%s, %s)
                    """,
                    (
                        regra_frequencia_id,
                        horario,
                    ),
                )

            for dia in frequencia_validada["dias_semana"]:
                cursor.execute(
                    """
                    INSERT INTO dias_semana_frequencia (
                        regra_frequencia_id,
                        dia_semana
                    )
                    VALUES (%s, %s)
                    """,
                    (
                        regra_frequencia_id,
                        dia,
                    ),
                )

            cursor.executemany(
                """
                INSERT INTO doses (
                    tratamento_id,
                    agendada_para,
                    status
                )
                VALUES (%s, %s, 'pendente')
                """,
                [(tratamento_id, dose) for dose in doses],
            )
    except Exception:
        logger.exception("Erro ao cadastrar tratamento")
        return resposta_erro_banco()

    return jsonify(
        {
            "mensagem": "Tratamento cadastrado com sucesso!",
            "tratamento_id": tratamento_id,
            "doses_geradas": len(doses),
        }
    ), 201


@tratamento.route("/tratamentos/ler-prescricao", methods=["POST"])
def ler_prescricao():
    _, erro_autenticacao = usuario_autenticado()
    if erro_autenticacao:
        return erro_autenticacao

    arquivo = request.files.get("arquivo")

    if not arquivo or not arquivo.filename:
        return jsonify({"erro": "Envie uma imagem ou PDF da prescrição!"}), 400

    nome = arquivo.filename.lower()
    extensoes_permitidas = (".png", ".jpg", ".jpeg", ".pdf")

    if not nome.endswith(extensoes_permitidas):
        return jsonify({
            "erro": "Formato inválido. Envie PNG, JPG, JPEG ou PDF."
        }), 400

    caminho = None

    try:
        # Cria um arquivo temporário; não armazena a prescrição no banco.
        extensao = os.path.splitext(nome)[1]

        with tempfile.NamedTemporaryFile(
            suffix=extensao, delete=False
        ) as temporario:
            caminho = temporario.name
            arquivo.save(caminho)

        
        resultado = processar_prescricao(caminho)

        dados = resultado.get("dados", {})
        medicamentos = dados.get("medicamentos", [])

        for medicamento in medicamentos:
            forma_original = medicamento.get("forma_consumo")
            forma_padronizada = normalizar_forma_consumo(
                forma_original
            )

            medicamento["forma_consumo"] = forma_padronizada

            if forma_padronizada is None:
                campos_duvidosos = medicamento.get("campos_duvidosos")

                if not isinstance(campos_duvidosos, list):
                    campos_duvidosos = []
                    medicamento["campos_duvidosos"] = campos_duvidosos

                if "forma_consumo" not in campos_duvidosos:
                    campos_duvidosos.append("forma_consumo")
            else:
                campos_duvidosos = medicamento.get("campos_duvidosos")

                if isinstance(campos_duvidosos, list):
                    medicamento["campos_duvidosos"] = [
                        campo for campo in campos_duvidosos
                        if campo != "forma_consumo"
                    ]

        return jsonify(resultado), 200


    except ValueError as erro:
        return jsonify({"erro": str(erro)}), 400

    except Exception:
        logger.exception("Erro ao processar prescrição")
        return jsonify({
            "erro": "Não foi possível ler a prescrição. Tente novamente."
        }), 500

    finally:
        if caminho and os.path.exists(caminho):
            os.remove(caminho)

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

            if not tratamento_encontrado:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404

            cursor.execute(
                """
                SELECT
                    id,
                    tipo,
                    intervalo_valor,
                    ancora_em,
                    fuso_horario,
                    ativo
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

                horarios = [
                    str(item["horario"])
                    for item in cursor.fetchall()
                ]

                cursor.execute(
                    """
                    SELECT dia_semana
                    FROM dias_semana_frequencia
                    WHERE regra_frequencia_id = %s
                    ORDER BY dia_semana
                    """,
                    (regra_id,),
                )

                dias_semana = [
                    item["dia_semana"]
                    for item in cursor.fetchall()
                ]

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

    except Exception:
        logger.exception("Erro ao buscar tratamento e frequência")
        return resposta_erro_banco()

    resposta = serializar_tratamento(tratamento_encontrado)
    resposta["frequencias"] = frequencias

    return jsonify(resposta), 200


@tratamento.route(
    "/tratamentos/<int:tratamento_id>/doses",
    methods=["GET"],
)
def listar_doses_tratamento(tratamento_id):
    usuario_id, erro_autenticacao = usuario_autenticado()

    if erro_autenticacao:
        return erro_autenticacao

    try:
        with sessao_banco() as (_, cursor):
            tratamento_encontrado = buscar_tratamento_do_usuario(
                cursor, tratamento_id, usuario_id
            )

            if not tratamento_encontrado:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404

            cursor.execute(
                """
                SELECT
                    id,
                    agendada_para,
                    status,
                    registrada_em
                FROM doses
                WHERE tratamento_id = %s
                ORDER BY agendada_para DESC, id DESC
                """,
                (tratamento_id,),
            )

            registros = cursor.fetchall()

    except Exception:
        logger.exception("Erro ao listar doses do tratamento")
        return resposta_erro_banco()

    
    agora = datetime.now(FUSO_HORARIO).replace(tzinfo=None)

    doses_atrasadas = []
    proximas_doses = []
    historico = []

    for registro in registros:
        dose = {
            chave: serializar_valor(valor)
            for chave, valor in registro.items()
        }

        agendada_para = registro["agendada_para"]
        status_dose = registro["status"]

        if status_dose in ("tomada", "nao_tomada"):
            dose["vencida"] = False
            historico.append(dose)

        elif status_dose == "pendente":
            vencida = agendada_para < agora
            dose["vencida"] = vencida

            if vencida:
                doses_atrasadas.append(dose)
            else:
                proximas_doses.append(dose)

    return jsonify({
        "tratamento_id": tratamento_id,
        "doses_atrasadas": doses_atrasadas,
        "proximas_doses": proximas_doses,
        "historico": historico,
    }), 200

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

    frequencia_validada, erro_frequencia = validar_frequencia(
        dados,
        tratamento_validado["data_inicio"],
        tratamento_validado["duracao_dias"],
    )
    if erro_frequencia:
        return jsonify({"erro": erro_frequencia}), 400
    
    doses, erro_doses = gerar_doses(frequencia_validada)
    if erro_doses:
        return jsonify({"erro": erro_doses}), 400

    try:
        with sessao_banco() as (_, cursor):
            existente = buscar_tratamento_do_usuario(
                cursor, tratamento_id, usuario_id, bloquear=True
            )
            if not existente:
                return jsonify({"erro": "Tratamento não encontrado!"}), 404
            if existente["status"] == "cancelado":
                return jsonify(
                    {"erro": "Tratamento cancelado não pode ser editado!"}
                ), 409

            cursor.execute(
                """
                SELECT id
                FROM regras_frequencia
                WHERE tratamento_id = %s
                AND ativo = 1
                FOR UPDATE
                """,
                (tratamento_id,),
            )

            regras_ativas = cursor.fetchall()

            if len(regras_ativas) != 1:
                return jsonify({
                    "erro": "O tratamento deve possuir exatamente uma regra de frequência ativa!"
                }), 409

            regra_atual = regras_ativas[0]

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

            cursor.execute(
                """
                UPDATE regras_frequencia
                SET
                    tipo = %s,
                    intervalo_valor = %s,
                    ancora_em = %s,
                    fuso_horario = %s
                WHERE id = %s
                """,
                (
                    frequencia_validada["tipo"],
                    frequencia_validada["intervalo_valor"],
                    frequencia_validada["ancora_em"],
                    FUSO_HORARIO.key,
                    regra_atual["id"],
                ),
            )

            cursor.execute(
                """
                DELETE FROM horarios_frequencia
                WHERE regra_frequencia_id = %s
                """,
                (regra_atual["id"],),
            )

            for horario in frequencia_validada["horarios"]:
                cursor.execute(
                    """
                    INSERT INTO horarios_frequencia (
                        regra_frequencia_id,
                        horario
                    )
                    VALUES (%s, %s)
                    """,
                    (
                        regra_atual["id"],
                        horario,
                    ),
                )

            cursor.execute(
                """
                DELETE FROM dias_semana_frequencia
                WHERE regra_frequencia_id = %s
                """,
                (regra_atual["id"],),
            )

            for dia in frequencia_validada["dias_semana"]:
                cursor.execute(
                    """
                    INSERT INTO dias_semana_frequencia (
                        regra_frequencia_id,
                        dia_semana
                    )
                    VALUES (%s, %s)
                    """,
                    (
                        regra_atual["id"],
                        dia,
                    ),
                )
            
            # Busca os horários que já possuem doses registradas.
            cursor.execute(
                """
                SELECT agendada_para
                FROM doses
                WHERE tratamento_id = %s
                  AND status IN ('tomada', 'nao_tomada')
                FOR UPDATE
                """,
                (tratamento_id,),
            )

            doses_preservadas = {
                dose["agendada_para"]
                for dose in cursor.fetchall()
            }

            # Remove doses pendentes que duplicam doses já registradas.
            cursor.execute(
                """
                DELETE FROM doses
                WHERE tratamento_id = %s
                  AND status = 'pendente'
                  AND agendada_para IN (
                      SELECT agendada_para
                      FROM (
                          SELECT agendada_para
                          FROM doses
                          WHERE tratamento_id = %s
                            AND status IN ('tomada', 'nao_tomada')
                      ) AS registradas
                  )
                """,
                (tratamento_id, tratamento_id),
            )

            # Remove as doses pendentes futuras para recriá-las
            # conforme a frequência atualizada.
            agora = datetime.now(FUSO_HORARIO).replace(tzinfo=None)

            cursor.execute(
                """
                DELETE FROM doses
                WHERE tratamento_id = %s
                  AND status = 'pendente'
                  AND agendada_para >= %s
                """,
                (tratamento_id, agora),
            )

            
            # Busca os horários que ainda possuem doses pendentes.
            cursor.execute(
                """
                SELECT agendada_para
                FROM doses
                WHERE tratamento_id = %s
                  AND status = 'pendente'
                FOR UPDATE
                """,
                (tratamento_id,),
            )

            doses_pendentes_existentes = {
                dose["agendada_para"]
                for dose in cursor.fetchall()
            }

            
            # Insere somente horários que não possuem dose preservada
            # nem dose pendente já existente.
            doses_novas = []
            horarios_adicionados = set()

            for dose in doses:
                if dose in doses_preservadas:
                    continue

                if dose in doses_pendentes_existentes:
                    continue

                if dose in horarios_adicionados:
                    continue

                doses_novas.append((tratamento_id, dose))
                horarios_adicionados.add(dose)

            if doses_novas:
                cursor.executemany(
                    """
                    INSERT INTO doses (
                        tratamento_id,
                        agendada_para,
                        status
                    )
                    VALUES (%s, %s, 'pendente')
                    """,
                    doses_novas,
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


@tratamento.route("/doses/<int:dose_id>", methods=["PATCH"])
def alterar_status_dose(dose_id):
    usuario_id, erro_autenticacao = usuario_autenticado()

    if erro_autenticacao:
        return erro_autenticacao

    dados = dados_json()

    if not dados:
        return jsonify({"erro": "Informe o status da dose!"}), 400

    novo_status, erro_status = normalizar_opcao(
        dados.get("status"),
        {"tomada", "nao_tomada"},
        "Status da dose",
    )

    if erro_status:
        return jsonify({"erro": erro_status}), 400

    try:
        with sessao_banco() as (_, cursor):
            cursor.execute(
                """
                SELECT d.id, d.agendada_para, d.status
                FROM doses AS d
                INNER JOIN tratamentos AS t
                    ON t.id = d.tratamento_id
                WHERE d.id = %s
                AND t.usuario_id = %s
                FOR UPDATE
                """,
                (dose_id, usuario_id),
            )

            dose = cursor.fetchone()

            if not dose:
                return jsonify({"erro": "Dose não encontrada!"}), 404

            if dose["status"] != "pendente":
                return jsonify({
                    "erro": "Esta dose já foi registrada e não pode ser alterada novamente!"
                }), 400

            agendada_para = dose["agendada_para"]
            agora = datetime.now(FUSO_HORARIO).replace(tzinfo=None)

            if agora < agendada_para:
                return jsonify({
                    "erro": "Não é possível registrar uma dose antes do horário agendado!"
                }), 400

            cursor.execute(
                """
                UPDATE doses
                SET status = %s,
                    registrada_em = CURRENT_TIMESTAMP
                WHERE id = %s
                """,
                (novo_status, dose_id),
            )

    except Exception:
        logger.exception("Erro ao alterar status da dose")
        return resposta_erro_banco()

    return jsonify({
        "mensagem": "Status da dose atualizado com sucesso!",
        "dose_id": dose_id,
        "status": novo_status,
    }), 200

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
