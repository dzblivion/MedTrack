import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import 'tratamento.dart';
import 'tratamento_repository.dart';

class TratamentosController extends ChangeNotifier {
  final TratamentoRepository _repositorio;

  List<Tratamento> _tratamentos = const [];
  bool _carregando = false;
  String? _erro;
  bool _descartado = false;

  TratamentosController(this._repositorio);

  bool get carregando => _carregando;
  String? get erro => _erro;

  List<Tratamento> get emAndamento =>
      _tratamentos.where((t) => t.status.emAndamento).toList();

  List<Tratamento> get finalizados =>
      _tratamentos.where((t) => !t.status.emAndamento).toList();

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();

    try {
      _tratamentos = await _repositorio.listar();
    } on ApiException catch (e) {
      _erro = e.mensagem;
    } catch (_) {
      _erro = 'Não foi possível carregar os tratamentos.';
    } finally {
      _carregando = false;
      _avisar();
    }
  }

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
