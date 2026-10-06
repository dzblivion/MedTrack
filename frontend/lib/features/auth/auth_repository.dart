import '../../core/api/api_client.dart';
import 'usuario.dart';

typedef Login = ({String token, Usuario usuario});

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<Login> login(String email, String senha) async {
    final dados = await _api.post('/login', {'email': email, 'senha': senha});

    return (
      token: dados['token'] as String,
      usuario: Usuario.fromJson(dados['usuario'] as Map<String, dynamic>),
    );
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

  Future<void> solicitarCodigo(String email) {
    return _api.post('/recuperar-senha', {'email': email});
  }

  Future<void> verificarCodigo(String email, String codigo) {
    return _api.post('/verificar-codigo', {'email': email, 'codigo': codigo});
  }

  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) {
    return _api.post('/redefinir-senha', {
      'email': email,
      'codigo': codigo,
      'nova_senha': novaSenha,
    });
  }
}
