import '../../core/api/api_client.dart';
import '../../core/storage/session_storage.dart';

class Usuario {
  final int id;
  final String nome;
  final String email;

  const Usuario({required this.id, required this.nome, required this.email});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nome: json['nome'] as String,
        email: json['email'] as String,
      );
}

class AuthRepository {
  final ApiClient _api;
  final SessionStorage _sessao;

  AuthRepository({ApiClient? api, SessionStorage? sessao})
      : _api = api ?? ApiClient(),
        _sessao = sessao ?? SessionStorage();

  Future<Usuario> login(String email, String senha) async {
    final dados = await _api.post('/login', {'email': email, 'senha': senha});

    await _sessao.salvarToken(dados['token'] as String);

    return Usuario.fromJson(dados['usuario'] as Map<String, dynamic>);
  }

  Future<void> cadastrarUsuario({
    required String nome,
    required String email,
    required String senha,
  }) {
    return _api.post('/cadastrar-usuario', {
      'nome': nome,
      'email': email,
      'senha': senha,
    });
  }

  Future<void> cadastrarProfissional({
    required String nome,
    required String email,
    required String senha,
    required String profissao,
    required String registro,
    required String ufRegistro,
  }) {
    return _api.post('/cadastrar-profissional', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'profissao': profissao,
      'registro': registro,
      'uf_registro': ufRegistro,
    });
  }
}
