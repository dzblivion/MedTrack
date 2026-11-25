import 'package:flutter/foundation.dart';

/// Avisa as telas que mostram tratamentos e doses (Início, Tratamentos e
/// Histórico) que um tratamento mudou em outra tela (ex.: cadastrado pela
/// MIA ou pausado no detalhe), para recarregarem sozinhas.
class Mudancas extends ChangeNotifier {
  void tratamentosMudaram() => notifyListeners();
}
