import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marca "MedTrack" em duas cores, usada no splash e no espaço vazio
/// do cabeçalho do login.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            children: [
              TextSpan(text: 'Med', style: TextStyle(color: Colors.white)),
              TextSpan(
                text: 'Track',
                style: TextStyle(color: AppColors.cianoClaro),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SEU TRATAMENTO, NO SEU RITMO.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
