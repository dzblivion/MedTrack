"""Rotina executada pelo serviço scheduler para manter doses contínuas planejadas."""

import logging

from routes.tratamento import repor_doses_continuas, sessao_banco

logging.basicConfig(level=logging.INFO)


def main():
    with sessao_banco() as (_, cursor):
        doses_inseridas = repor_doses_continuas(cursor)
    print(f"Doses contínuas repostas: {doses_inseridas}")


if __name__ == "__main__":
    main()
