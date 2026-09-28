import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marca "MedTrack" em duas cores.
///
/// [claro] controla a variante: `false` (padrão) é pensada para fundo teal
/// sólido, como no login; `true` é pensada para fundo claro, como no splash.
class AppLogo extends StatelessWidget {
  final bool claro;

  const AppLogo({super.key, this.claro = false});

  @override
  Widget build(BuildContext context) {
    final corMed = claro ? AppColors.darkCiano : Colors.white;
    final corTrack = claro ? AppColors.ciano : AppColors.cianoClaro;
    final corTagline = claro ? AppColors.gray : Colors.white70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            children: [
              TextSpan(text: 'Med', style: TextStyle(color: corMed)),
              TextSpan(text: 'Track', style: TextStyle(color: corTrack)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SEU TRATAMENTO, NO SEU RITMO.',
          style: TextStyle(
            color: corTagline,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
