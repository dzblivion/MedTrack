import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Caixa clara com o ícone de "i", usada como dica nas etapas.
class AvisoInfo extends StatelessWidget {
  final String texto;

  const AvisoInfo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cianoClaro,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.darkCiano, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: AppColors.darkCiano,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
