import 'package:flutter/foundation.dart';

import '../../core/mudancas.dart';
import 'compartilhamento.dart';
import 'compartilhamento_repository.dart';

/// Pedidos de acesso esperando o paciente (para o aviso no Início).
class PedidosController extends ChangeNotifier {
  final CompartilhamentoRepository _repositorio;
  final Mudancas? _mudancas;

  List<PedidoDeAcesso> _pedidos = const [];
  bool _descartado = false;

  PedidosController(this._repositorio, {this._mudancas}) {
    _mudancas?.addListener(carregar);
  }

  List<PedidoDeAcesso> get pedidos => _pedidos;

  /// Sem pedidos (ou se falhar), o aviso simplesmente não aparece.
  Future<void> carregar() async {
    try {
      _pedidos = await _repositorio.pedidosPendentes();
      if (!_descartado) notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _mudancas?.removeListener(carregar);
    _descartado = true;
    super.dispose();
  }
}
