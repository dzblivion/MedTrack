import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Botão em pílula com "+" ao lado do avatar ("Novo tratamento",
/// "Nova prescrição").
class BotaoCabecalho extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;

  const BotaoCabecalho({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(texto),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ciano,
        foregroundColor: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.6),
        elevation: 6,
        textStyle: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        // Em formato de pílula, na proporção do avatar (48) ao lado.
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(0, 36),
        shape: const StadiumBorder(),
      ),
    );
  }
}
