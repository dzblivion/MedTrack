import os

from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential
from dotenv import load_dotenv

load_dotenv()

endpoint = os.getenv("AZURE_DOCUMENT_ENDPOINT")
key = os.getenv("AZURE_DOCUMENT_KEY")

cliente = DocumentIntelligenceClient(
    endpoint=endpoint,
    credential=AzureKeyCredential(key)
)

def ler_imagem(caminho_arquivo):
    with open(caminho_arquivo, "rb") as arquivo:
        poller = cliente.begin_analyze_document(
            "prebuilt-read",
            body=arquivo,
            locale="pt"
        )

    resultado = poller.result()

    return resultado.content