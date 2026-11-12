import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import 'cartao.dart';

/// "Adesão de hoje": doses tomadas sobre as agendadas no dia.
class CardAdesao extends StatelessWidget {
  final int tomadas;
  final int total;

  const CardAdesao({super.key, required this.tomadas, required this.total});

  @override
  Widget build(BuildContext context) {
    final fracao = total == 0 ? 0.0 : tomadas / total;
    final pequeno = GoogleFonts.poppins(color: AppColors.gray, fontSize: 10);

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Adesão de hoje', style: estiloTituloCartao),
              Text(
                total == 0 ? 'sem doses hoje' : '$tomadas de $total doses',
                style: pequeno,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fracao,
              minHeight: 10,
              backgroundColor: AppColors.field,
              color: AppColors.ciano,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(fracao * 100).round()}%', style: pequeno),
          ),
        ],
      ),
    );
  }
}
