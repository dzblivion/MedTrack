import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import 'cartao.dart';

/// Convite para a MIA, que lê a prescrição e preenche o tratamento.
class CardMia extends StatelessWidget {
  final VoidCallback onConhecer;

  const CardMia({super.key, required this.onConhecer});

  @override
  Widget build(BuildContext context) {
    final titulo = GoogleFonts.poppins(
      color: AppColors.inputText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                color: AppColors.ciano,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: titulo,
                    children: [
                      const TextSpan(text: 'A '),
                      TextSpan(
                        text: 'MIA',
                        style: titulo.copyWith(
                          color: AppColors.ciano,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: ' está aqui pra ajudar!'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Envie sua prescrição e deixe a MIA organizar as informações do '
            'seu tratamento.',
            style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 10),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onConhecer,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('Conhecer a MIA'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ciano,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
