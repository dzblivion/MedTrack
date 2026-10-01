# MedTrack

Sistema de gestão de saúde pessoal: acompanhamento de tratamentos, doses e adesão.

| Pasta | Conteúdo |
|---|---|
| `frontend/` | App Flutter |
| `backend/` | API em Python (Flask) |
| `database/` | Estrutura do banco MySQL (`medtrack.sql`) |

## Rodando o backend com Docker

Sobe a API e o banco MySQL 8 já com as tabelas, sem instalar Python nem MySQL.

### Pré-requisito
[Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e aberto.

### Primeira vez
1. Na pasta `backend/`, copie `.env.example` para `.env`.
2. No `.env`, preencha pelo menos o `JWT_SECRET` com um texto longo e aleatório. Para gerar um:
   ```
   python -c "import secrets; print(secrets.token_hex(32))"
   ```
   Para a recuperação de senha enviar e-mail, preencha também `MAIL_USERNAME` e `MAIL_PASSWORD`.
3. Na raiz do projeto:
   ```
   docker compose up -d --build
   ```
4. Acesse http://localhost:5000. A resposta deve ser "Conexão com o banco de dados estabelecida com sucesso!".

O app Flutter já aponta para `localhost:5000` (navegador e Windows) e `10.0.2.2:5000` (emulador Android), então funciona sem configuração extra.

### Comandos do dia a dia
| Comando | O que faz |
|---|---|
| `docker compose up -d` | Liga a API e o banco |
| `docker compose down` | Desliga tudo (os dados do banco são mantidos) |
| `docker compose logs -f api` | Mostra o log da API |
| `docker compose up -d --build` | Liga reconstruindo a API (depois de mudar o `requirements.txt` ou o código) |
| `docker compose down -v` | Desliga e **apaga o banco**, para recriar do zero a partir de `database/` |

### Banco de dados
- Os arquivos `.sql` de `database/` só rodam **na primeira vez** que o banco é criado. Depois de alterar a estrutura, rode `docker compose down -v` e suba de novo (os dados de teste são apagados).
- Para abrir o banco num cliente como o MySQL Workbench: host `127.0.0.1`, porta `3307`, usuário `medtrack`, senha `medtrack`.
- Essas credenciais são só do ambiente local de desenvolvimento.
