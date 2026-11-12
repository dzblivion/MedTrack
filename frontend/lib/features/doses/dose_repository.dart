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
    final ativos = (await _tratamentos.listar())
        .where((t) => t.status == StatusTratamento.ativo);
    final porTratamento = await Future.wait(ativos.map(_dosesDe));

    return [
      for (final doses in porTratamento)
        for (final dose in doses)
          if (_mesmoDia(dose.agendadaPara, dia)) dose,
    ]..sort((a, b) => a.agendadaPara.compareTo(b.agendadaPara));
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
