import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/cabecalho_usuario.dart';
import '../auth/sessao_controller.dart';
import 'historico_controller.dart';
import 'widgets/lista_historico.dart';

/// Aba Histórico: doses que já passaram, de todos os tratamentos,
/// agrupadas por dia, com filtro por mês.
class HistoricoScreen extends StatelessWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HistoricoController>();
    final nome = context.watch<SessaoController>().usuario?.nome ?? '';

    // Na primeira vez que a tela aparece, busca os dados.
    if (!controller.iniciado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.iniciado) controller.carregar();
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoUsuario(nome: nome),
            const SizedBox(height: 25),
            const Text(
              'Seu histórico:',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.title,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'Acompanhe suas doses registradas.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.gray,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(child: ListaHistorico()),
          ],
        ),
      ),
    );
  }
}
