import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Conteúdo provisório das abas que ainda não foram construídas.
class EmConstrucao extends StatelessWidget {
  final String titulo;
  final Widget? acao;

  const EmConstrucao({super.key, required this.titulo, this.acao});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_outlined,
              size: 40,
              color: AppColors.gray,
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: const TextStyle(
                color: AppColors.darkCiano,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Em construção',
              style: TextStyle(color: AppColors.gray, fontSize: 12),
            ),
            if (acao != null) ...[const SizedBox(height: 20), acao!],
          ],
        ),
      ),
    );
  }
}
