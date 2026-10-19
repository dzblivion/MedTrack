import '../../core/api/api_client.dart';
import 'dados_tratamento.dart';
import 'tratamento.dart';

class TratamentoRepository {
  static const _porPagina = 100;

  final ApiClient _api;

  TratamentoRepository(this._api);

  /// Todos os tratamentos do usuário. A API devolve no máximo 100 por vez.
  Future<List<Tratamento>> listar() async {
    final tratamentos = <Tratamento>[];

    while (true) {
      final dados = await _api.get(
        '/tratamentos',
        query: {'limit': '$_porPagina', 'offset': '${tratamentos.length}'},
      );
      final pagina = (dados['tratamentos'] as List)
          .map((item) => Tratamento.fromJson(item as Map<String, dynamic>))
          .toList();

      tratamentos.addAll(pagina);
      if (pagina.length < _porPagina) return tratamentos;
    }
  }

  Future<void> criar(DadosTratamento dados) =>
      _api.post('/tratamentos', dados.toJson());

  Future<void> atualizar(int id, DadosTratamento dados) =>
      _api.put('/tratamentos/$id', dados.toJson());
}
