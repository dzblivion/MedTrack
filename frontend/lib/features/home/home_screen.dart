import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../auth/sessao_controller.dart';

// Provisória: será substituída pela Home do protótipo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<SessaoController>().usuario;

    return SafeArea(
      child: Center(
        child: Text(
          'Olá, ${usuario?.nome ?? ''}!',
          style: const TextStyle(
            color: AppColors.darkCiano,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
