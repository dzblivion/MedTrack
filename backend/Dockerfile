FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

# O app.run() do app.py só escuta em 127.0.0.1, inacessível de fora do container.
CMD ["flask", "--app", "app", "run", "--host", "0.0.0.0", "--port", "5000"]
