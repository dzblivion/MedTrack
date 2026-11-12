import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../doses/dose.dart';
import '../doses/dose_repository.dart';

class HomeController extends ChangeNotifier {
  final DoseRepository _repositorio;

  /// Trocável nos testes, para fixar "agora".
  final DateTime Function() _relogio;

  List<Dose> _doses = const [];
  bool _carregando = false;
  String? _erro;
  int? _registrando;
  bool _descartado = false;

  /// Redesenha de tempos em tempos para "atrasada" e os botões acompanharem
  /// o relógio sem precisar recarregar.
  Timer? _tique;

  HomeController(this._repositorio, {DateTime Function()? relogio})
      : _relogio = relogio ?? DateTime.now {
    _tique = Timer.periodic(const Duration(seconds: 30), (_) => _avisar());
  }

  /// Todas as doses de hoje, em ordem de horário.
  List<Dose> get doses => _doses;

  bool get carregando => _carregando;
  String? get erro => _erro;
  DateTime get agora => _relogio();

  /// Id da dose sendo registrada (para mostrar o carregando no botão).
  int? get registrando => _registrando;

  /// Primeiro a pendente mais antiga que já passou do horário (atrasada ou
  /// na hora); se não houver, a próxima que ainda vai chegar.
  Dose? get proximaDose {
    final pendentes = _doses.where((d) => d.pendente);
    final agora = this.agora;
    for (final dose in pendentes) {
      if (dose.podeRegistrar(agora)) return dose;
    }
    return pendentes.isEmpty ? null : pendentes.first;
  }

  int get totalHoje => _doses.length;
  int get tomadasHoje => _doses.where((d) => d.status == StatusDose.tomada).length;

  /// De 0 a 1.
  double get adesao => totalHoje == 0 ? 0 : tomadasHoje / totalHoje;

  bool get semDoses => _doses.isEmpty;

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();

    try {
      _doses = await _repositorio.doDia(agora);
    } on ApiException catch (e) {
      _erro = e.mensagem;
    } catch (_) {
      _erro = 'Não foi possível carregar as doses de hoje.';
    } finally {
      _carregando = false;
      _avisar();
    }
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

  // A tela pode ser fechada (ex.: logout) antes de a API responder.
  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _tique?.cancel();
    _descartado = true;
    super.dispose();
  }
}
