import '../../core/api/api_client.dart';
import '../tratamentos/tratamento.dart';
import '../tratamentos/tratamento_repository.dart';
import 'dose.dart';

class DoseRepository {
  final ApiClient _api;
  final TratamentoRepository _tratamentos;

  DoseRepository(this._api, this._tratamentos);

  /// Doses do dia [dia], em ordem de horário, dos tratamentos ativos.
  ///
  /// O backend ainda não tem uma rota com as doses de todos os tratamentos
  /// (o Antonio está fazendo). Por enquanto buscamos as doses de cada
  /// tratamento e juntamos; quando a rota chegar, só este método muda.
  Future<List<Dose>> doDia(DateTime dia) async {
    final doses = await _dosesDos(
      (t) => t.status == StatusTratamento.ativo,
    );
    return [
      for (final dose in doses)
        if (_mesmoDia(dose.agendadaPara, dia)) dose,
    ]..sort((a, b) => a.agendadaPara.compareTo(b.agendadaPara));
  }

  /// Todas as doses de todos os tratamentos, inclusive concluídos,
  /// pausados e cancelados, da mais recente para a mais antiga.
  /// (Mesma limitação de [doDia]: hoje o backend não filtra por data.)
  Future<List<Dose>> todas() async {
    final doses = await _dosesDos((_) => true);
    return doses..sort((a, b) => b.agendadaPara.compareTo(a.agendadaPara));
  }

  /// Doses pendentes de agora em diante dos tratamentos ativos, da mais
  /// próxima para a mais distante (para os lembretes).
  Future<List<Dose>> proximas(DateTime agora) async {
    final doses = await _dosesDos((t) => t.status == StatusTratamento.ativo);
    return [
      for (final dose in doses)
        if (dose.pendente && dose.agendadaPara.isAfter(agora)) dose,
    ]..sort((a, b) => a.agendadaPara.compareTo(b.agendadaPara));
  }

  /// Horário da próxima dose pendente do tratamento (nulo se não houver).
  /// O backend não cria doses em horários que já passaram, então logo
  /// depois do cadastro esta é a primeira dose.
  Future<DateTime?> primeiraPendente(int tratamentoId) async {
    final dados = await _api.get('/tratamentos/$tratamentoId/doses');
    final horarios = [
      for (final lista in ['doses_atrasadas', 'proximas_doses'])
        for (final item in dados[lista] as List? ?? const [])
          DateTime.parse((item as Map<String, dynamic>)['agendada_para'] as String),
    ]..sort();
    return horarios.firstOrNull;
  }

  /// Todas as doses de um tratamento (para a contagem no detalhe).
  Future<List<Dose>> doTratamento(Tratamento tratamento) =>
      _dosesDe(tratamento);

  Future<List<Dose>> _dosesDos(bool Function(Tratamento) incluir) async {
    final tratamentos = (await _tratamentos.listar()).where(incluir);
    final porTratamento = await Future.wait(tratamentos.map(_dosesDe));
    return [for (final doses in porTratamento) ...doses];
  }

  Future<void> registrar(int id, {required bool tomada}) => _api.patch(
        '/doses/$id',
        {'status': tomada ? StatusDose.tomada.api : StatusDose.naoTomada.api},
      );

  /// A rota separa as doses em 3 listas; aqui elas viram uma só.
  Future<List<Dose>> _dosesDe(Tratamento tratamento) async {
    final dados = await _api.get('/tratamentos/${tratamento.id}/doses');
    return [
      for (final lista in ['doses_atrasadas', 'proximas_doses', 'historico'])
        for (final item in dados[lista] as List? ?? const [])
          Dose.fromJson(item as Map<String, dynamic>, tratamento),
    ];
  }

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
