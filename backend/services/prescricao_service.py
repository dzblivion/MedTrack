

from services.ai_service import estruturar_prescricao
from services.ocr_service import ler_imagem


def processar_prescricao(caminho_arquivo: str) -> dict:
    # 1. Extrai o texto da imagem ou do PDF pela Azure OCR.
    texto_ocr = ler_imagem(caminho_arquivo)

    if not isinstance(texto_ocr, str) or not texto_ocr.strip():
        raise ValueError(
            "Nenhum texto foi encontrado na prescrição. "
            "Envie uma imagem mais nítida ou um PDF legível."
        )

    # 2. Envia o texto para a MIA estruturar os medicamentos.
    dados = estruturar_prescricao(texto_ocr)

    # 3. Confere a estrutura básica retornada pela IA.
    if not isinstance(dados, dict) or not isinstance(
        dados.get("medicamentos"), list
    ):
        raise TypeError(
            "A IA não retornou a lista de medicamentos esperada."
        )

    # 4. Devolve os dados para revisão, sem salvar no banco.
    return {
        "texto_extraido": texto_ocr,
        "dados": dados,
    }

