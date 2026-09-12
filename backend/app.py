from config.database import banco
from flask import Flask
from flask_cors import CORS
from routes.usuario import usuario

app = Flask(__name__)
CORS(app)

app.register_blueprint(usuario)


@app.route('/')
def home():
    conexao = banco()
    conexao.close()
    return 'Conexão com o banco de dados estabelecida com sucesso!'


if __name__ == '__main__':
    app.run(debug=True)