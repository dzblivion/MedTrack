import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/formatos.dart';
import '../doses/dose.dart';
import '../doses/dose_repository.dart';

/// Doses de um dia no histórico, da mais recente para a mais antiga.
typedef DiaDoHistorico = ({DateTime dia, List<Dose> doses});

class HistoricoController extends ChangeNotifier {
  final DoseRepository _repositorio;

  /// Trocável nos testes, para fixar "agora".
  final DateTime Function() _relogio;

  /// Só as doses que já chegaram no horário, da mais recente à mais antiga.
  List<Dose> _doses = const [];
  bool _carregando = false;
  bool _iniciado = false;
  String? _erro;
  int? _registrando;
  int _buscas = 0;
  bool _descartado = false;

  /// Primeiro dia do mês escolhido no filtro.
  late DateTime _mes = _inicioDoMes(agora);

  HistoricoController(this._repositorio, {DateTime Function()? relogio})
      : _relogio = relogio ?? DateTime.now;

  DateTime get agora => _relogio();
  DateTime get mes => _mes;
  bool get carregando => _carregando;
  String? get erro => _erro;
  int? get registrando => _registrando;

  /// Já pediu os dados alguma vez (a tela usa para buscar na 1ª abertura).
  bool get iniciado => _iniciado;

  /// Não há histórico antes da primeira dose nem depois do mês atual.
  bool get podeVoltar {
    if (_doses.isEmpty) return false;
    return _mes.isAfter(_inicioDoMes(_doses.last.agendadaPara));
  }

  bool get podeAvancar => _mes.isBefore(_inicioDoMes(agora));

  void mesAnterior() {
    if (!podeVoltar) return;
    _mes = DateTime(_mes.year, _mes.month - 1);
    _avisar();
  }

  void proximoMes() {
    if (!podeAvancar) return;
    _mes = DateTime(_mes.year, _mes.month + 1);
    _avisar();
  }

  /// Dias do mês escolhido que têm doses, do mais recente ao mais antigo.
  List<DiaDoHistorico> get dias {
    final porDia = <DateTime, List<Dose>>{};
    for (final dose in _doses) {
      final quando = dose.agendadaPara;
      if (quando.year != _mes.year || quando.month != _mes.month) continue;
      porDia
          .putIfAbsent(DateTime(quando.year, quando.month, quando.day), () => [])
          .add(dose);
    }
    // As doses já vêm em ordem decrescente, então os dias também.
    return [for (final e in porDia.entries) (dia: e.key, doses: e.value)];
  }

  /// "Hoje – quinta, 19/11", "Ontem – ...", "Anteontem – ..." ou só a data.
  String rotuloDoDia(DateTime dia) {
    final hoje = agora;
    final diferenca = DateTime.utc(hoje.year, hoje.month, hoje.day)
        .difference(DateTime.utc(dia.year, dia.month, dia.day))
        .inDays;
    final data = '${diaDaSemana(dia)}, ${formatarDiaMes(dia)}';
    return switch (diferenca) {
      0 => 'Hoje – $data',
      1 => 'Ontem – $data',
      2 => 'Anteontem – $data',
      _ => data,
    };
  }

  Future<void> carregar() async {
    // Só a busca mais recente vale (ex.: abrir a aba enquanto carrega).
    final busca = ++_buscas;
    _iniciado = true;
    _carregando = true;
    _erro = null;
    _avisar();

    List<Dose>? doses;
    String? erro;
    try {
      final agora = this.agora;
      doses = [
        for (final dose in await _repositorio.todas())
          if (!dose.agendadaPara.isAfter(agora)) dose,
      ];
    } on ApiException catch (e) {
      erro = e.mensagem;
    } catch (_) {
      erro = 'Não foi possível carregar o histórico.';
    }

    if (busca != _buscas) return;
    if (doses != null) _doses = doses;
    _erro = erro;
    _carregando = false;
    _avisar();
  }

  /// Registra e recarrega. Erros da API sobem para a tela mostrar.
  Future<void> registrar(Dose dose, {required bool tomada}) async {
    _registrando = dose.id;
    _avisar();
    try {
      await _repositorio.registrar(dose.id, tomada: tomada);
      await carregar();
    } finally {
      _registrando = null;
      _avisar();
    }
  }

  static DateTime _inicioDoMes(DateTime data) =>
      DateTime(data.year, data.month);

  // A tela pode ser fechada (ex.: logout) antes de a API responder.
  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
