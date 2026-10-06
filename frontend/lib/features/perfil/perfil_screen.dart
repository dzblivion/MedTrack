import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/em_construcao.dart';
import '../auth/sessao_controller.dart';

// Provisória: só o "Sair da conta". O Perfil do protótipo vem na próxima etapa.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmConstrucao(
      titulo: 'Perfil',
      acao: TextButton(
        onPressed: () => context.read<SessaoController>().sair(),
        child: const Text(
          'Sair da conta',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
