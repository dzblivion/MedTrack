import os

from config.database import banco
from config.mail import mail
from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS
from routes.usuario import usuario

load_dotenv()

app = Flask(__name__)
CORS(app)

app.config["MAIL_SERVER"] = "smtp.gmail.com"
app.config["MAIL_PORT"] = 587
app.config["MAIL_USE_TLS"] = True
app.config["MAIL_USERNAME"] = os.getenv("MAIL_USERNAME")
app.config["MAIL_PASSWORD"] = os.getenv("MAIL_PASSWORD")

mail.init_app(app)

app.register_blueprint(usuario)


@app.route('/')
def home():
    conexao = banco()
    conexao.close()
    return 'Conexão com o banco de dados estabelecida com sucesso!'


if __name__ == '__main__':
    app.run(debug=True)