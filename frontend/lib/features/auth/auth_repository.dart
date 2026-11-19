import '../../core/api/api_client.dart';
import 'dados_cadastro.dart';
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

  /// Envia o código de 6 dígitos para confirmar o e-mail do cadastro.
  Future<void> solicitarCodigoCadastro(String email) {
    return _api.post('/solicitar-codigo-cadastro', {'email': email});
  }

  /// Cria a conta; o backend confere o [codigo] enviado por e-mail.
  Future<void> cadastrar(DadosCadastro dados, String codigo) {
    final rota = dados.profissional == null
        ? '/cadastrar-usuario'
        : '/cadastrar-profissional';
    return _api.post(rota, dados.toJson(codigo));
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
