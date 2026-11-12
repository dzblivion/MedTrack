import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Topo de cada etapa: voltar, "Etapa X de N", ícone, título e progresso.
class CabecalhoEtapa extends StatelessWidget {
  /// Começa em 1.
  final int etapa;
  final int total;
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onVoltar;

  const CabecalhoEtapa({
    super.key,
    required this.etapa,
    required this.total,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox.square(
              dimension: 28,
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Voltar',
                padding: EdgeInsets.zero,
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cianoClaro,
                  foregroundColor: AppColors.darkCiano,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onVoltar,
              ),
            ),
            Text(
              'Etapa $etapa de $total',
              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.gray),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.cianoClaro,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icone, color: AppColors.darkCiano, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inputText,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 1; i <= total; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= etapa ? AppColors.ciano : AppColors.field,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
