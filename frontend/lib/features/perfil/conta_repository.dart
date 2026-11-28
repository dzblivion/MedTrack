import '../../core/api/api_client.dart';

/// Dados da própria conta: trocar o nome e excluir.
class ContaRepository {
  final ApiClient _api;

  ContaRepository(this._api);

  /// Devolve o nome como ficou salvo (o backend tira os espaços das pontas).
  Future<String> alterarNome(String nome) async {
    final dados = await _api.patch('/usuarios/me', {'nome': nome});
    return dados['nome'] as String? ?? nome.trim();
  }

  /// Apaga a conta e tudo dela (tratamentos, doses, compartilhamentos e
  /// foto). A senha atual confirma que é a própria pessoa.
  Future<void> excluir(String senha) =>
      _api.delete('/usuarios/me', {'senha': senha});
}
