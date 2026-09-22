import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../auth/auth_repository.dart';

// Provisória: será substituída pela Home do protótipo.
class HomeScreen extends StatelessWidget {
  final Usuario usuario;

  const HomeScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Olá, ${usuario.nome}!',
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
