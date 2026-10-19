import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/rotas.dart';
import '../sessao_controller.dart';

/// Volta para a tela anterior (Login, Perfil ou o passo anterior do fluxo).
/// Aberta direto pelo endereço, sem tela anterior, vai para o Perfil ou o Login.
void voltarDaRecuperacao(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final logado = context.read<SessaoController>().logado;
  context.go(logado ? Rotas.perfil : Rotas.login);
}
