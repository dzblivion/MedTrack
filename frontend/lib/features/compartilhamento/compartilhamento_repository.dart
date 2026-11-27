import '../../core/api/api_client.dart';
import 'compartilhamento.dart';

/// Rotas de compartilhamento entre paciente e profissional.
class CompartilhamentoRepository {
  final ApiClient _api;

  CompartilhamentoRepository(this._api);

  // ---------- Paciente ----------

  /// Gera o código para o profissional. O backend só mostra o código
  /// nesta resposta; ele vale até ser usado ou revogado.
  Future<String> gerarCodigo(int tratamentoId) async {
    final dados = await _api.post('/compartilhamentos', {
      'tratamento_id': tratamentoId,
    });
    return dados['codigo'] as String;
  }

  Future<List<CompartilhamentoDoPaciente>> listarDoPaciente() async {
    final dados = await _api.get('/compartilhamentos');
    return [
      for (final item in dados['compartilhamentos'] as List? ?? const [])
        CompartilhamentoDoPaciente.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<PedidoDeAcesso>> pedidosPendentes() async {
    final dados = await _api.get('/compartilhamentos/solicitacoes');
    return [
      for (final item in dados['solicitacoes'] as List? ?? const [])
        PedidoDeAcesso.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> decidir(int compartilhamentoId, {required bool aprovar}) =>
      _api.patch('/compartilhamentos/$compartilhamentoId/decisao', {
        'decisao': aprovar ? 'aprovar' : 'recusar',
      });

  /// Tira o acesso do profissional (ou invalida um código não usado).
  Future<void> revogar(int compartilhamentoId) =>
      _api.delete('/compartilhamentos/$compartilhamentoId');

  // ---------- Profissional ----------

  /// Usa o código do paciente: vira um pedido que ele precisa aprovar.
  Future<void> usarCodigo(String codigo) =>
      _api.post('/compartilhamentos/validar', {'codigo': codigo.trim()});

  /// Tratamentos com acesso aprovado.
  Future<List<TratamentoDePaciente>> listarDoProfissional() async {
    final dados = await _api.get('/compartilhamentos/profissional');
    return [
      for (final item in dados['compartilhamentos'] as List? ?? const [])
        TratamentoDePaciente.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<DetalheCompartilhado> buscar(int compartilhamentoId) async =>
      DetalheCompartilhado.fromJson(
        await _api.get('/compartilhamentos/$compartilhamentoId'),
      );
}
