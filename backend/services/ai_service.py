
import json
import os
import time

from google import genai
from google.genai import types
from google.genai.errors import ServerError


def estruturar_prescricao(texto_ocr: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        raise ValueError("GEMINI_API_KEY não está configurada.")

    modelo = os.getenv("GEMINI_MODEL", "gemini-3.6-flash")
    client = genai.Client(api_key=api_key)

    resposta = None
    max_tentativas = 3

    for tentativa in range(max_tentativas):
        try:
            resposta = client.models.generate_content(
                model=modelo,
                contents=f"""
                ### Instruções da MIA — interpretação de prescrições

                Você é a MIA, assistente de leitura de prescrições do MedTrack. Sua função é interpretar o texto extraído por OCR de uma prescrição médica e organizar as informações em um JSON estruturado.

                1. Identificação dos medicamentos
                - Identifique todos os medicamentos presentes no texto.
                - Cada medicamento deve ser representado por um objeto independente dentro da lista `medicamentos`.
                - Preserve o nome comercial, princípio ativo e apresentação quando estiverem disponíveis no texto.
                - Corrija erros evidentes do OCR usando o contexto da prescrição.
                - Considere estas correções conhecidas:
                - `Daivabet` ou `Daivabet gel` → `Daivobet` ou `Daivobet gel`.
                - `Doctor Plus` → `Doctar`.
                - `Omega fori` → `Omega For`.
                - Essas correspondências são referências para corrigir os erros específicos acima. Não substitua automaticamente outros nomes parecidos sem evidências suficientes.
                - Se não conseguir determinar o nome com segurança, mantenha a melhor leitura possível e inclua `medicamento` em `campos_duvidosos`.

                2. Forma farmacêutica e forma de consumo
                - Identifique a apresentação do medicamento quando estiver indicada, como comprimido, cápsula, solução, shampoo, gel ou creme.
                - Preencha `forma_consumo` com a maneira de utilização ou via de administração indicada pela prescrição, conforme o significado esperado pelo sistema.
                - Diferencie apresentação farmacêutica de via de administração: por exemplo, shampoo é uma apresentação; uso tópico é uma via de administração.
                - Use o contexto da prescrição para identificar se o medicamento é de uso oral, tópico, oftálmico, inalatório ou outra via explicitamente indicada.
                - Não presuma a via de administração apenas pelo nome comercial.
                - Se não houver informação suficiente para determinar `forma_consumo`, retorne `null` e inclua `forma_consumo` em `campos_duvidosos`.

                3. Dosagem e instruções de uso
                - Extraia `dosagem_valor`, `dosagem_unidade`, `quantidade_por_dose`, `frequencia_texto`, `duracao_texto` e `data_inicio` somente quando houver evidências no texto.
                - Não confunda a concentração do medicamento com a quantidade utilizada em cada dose.
                - Preserve as instruções de frequência e duração sem alterá-las.
                - Se uma informação estiver ausente ou ilegível, retorne `null` no campo correspondente.
                - Inclua em `campos_duvidosos` os campos que estejam ilegíveis, contraditórios ou cuja interpretação seja incerta. Não marque como duvidoso um campo apenas porque ele não aparece na prescrição.

                4. Regras de segurança e fidelidade
                - O texto do OCR é a fonte principal da extração. Use o contexto para interpretar erros, não para inventar informações.
                - Nunca crie medicamentos, doses, frequências, durações ou datas.
                - Não transforme uma suposição em uma informação confirmada.
                - Não misture instruções de medicamentos diferentes.
                - Se houver divergência ou incerteza que possa alterar o uso do medicamento, sinalize o campo para revisão humana.
                - Retorne exclusivamente o JSON no formato solicitado pelo schema, sem explicações adicionais.

                O campo forma_consumo deve usar exclusivamente um destes valores:
                oral, sublingual, topica, injetavel, inalatoria,
                oftalmica, nasal, retal, vaginal ou outra.

                Não inclua expressões como "uso oral" ou "uso tópico":
                retorne apenas o valor padronizado.

                Se a via não puder ser determinada com segurança,
                retorne null e inclua "forma_consumo" em campos_duvidosos.

                **Texto extraído pelo OCR:**
                {texto_ocr}
                """,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema={
                        "type": "OBJECT",
                        "properties": {
                            "medicamentos": {
                                "type": "ARRAY",
                                "items": {
                                    "type": "OBJECT",
                                    "properties": {
                                        "medicamento": {
                                            "anyOf": [
                                                {"type": "STRING"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "dosagem_valor": {
                                            "anyOf": [
                                                {"type": "NUMBER"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "dosagem_unidade": {
                                            "anyOf": [
                                                {"type": "STRING"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "quantidade_por_dose": {
                                            "anyOf": [
                                                {"type": "NUMBER"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "forma_consumo": {
                                            "anyOf": [
                                                {"type": "STRING"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "frequencia_texto": {
                                            "anyOf": [
                                                {"type": "STRING"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "duracao_texto": {
                                            "anyOf": [
                                                {"type": "STRING"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "data_inicio": {
                                            "anyOf": [
                                                {"type": "STRING"},
                                                {"type": "NULL"},
                                            ]
                                        },
                                        "campos_duvidosos": {
                                            "type": "ARRAY",
                                            "items": {"type": "STRING"},
                                        },
                                    },
                                    "required": [
                                        "medicamento",
                                        "dosagem_valor",
                                        "dosagem_unidade",
                                        "quantidade_por_dose",
                                        "forma_consumo",
                                        "frequencia_texto",
                                        "duracao_texto",
                                        "data_inicio",
                                        "campos_duvidosos",
                                    ],
                                },
                            }
                        },
                        "required": ["medicamentos"],
                    },
                ),
            )
            break

        except ServerError as erro:
            if erro.code != 503 or tentativa == max_tentativas - 1:
                raise

            espera = 2 ** (tentativa + 1)
            print(
                f"A MIA está temporariamente indisponível. "
                f"Tentativa {tentativa + 1}/{max_tentativas}. "
                f"Nova tentativa em {espera} segundos."
            )
            time.sleep(espera)


    
    if resposta is None or not resposta.text:
        raise ValueError("A IA não retornou uma resposta.")

    try:
        dados = json.loads(resposta.text)
    except (json.JSONDecodeError, TypeError) as erro:
        raise ValueError(
            "A IA retornou uma resposta que não é um JSON válido."
        ) from erro

    if not isinstance(dados, dict) or not isinstance(
        dados.get("medicamentos"), list
    ):
        raise TypeError(
            "A resposta da IA não contém a lista de medicamentos esperada."
        )

    return dados

