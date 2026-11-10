import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Avatar com a inicial + nome, no topo das abas do app (como no Figma).
class CabecalhoUsuario extends StatelessWidget {
  final String nome;
  final String? subtitulo;
  final Widget? acao;

  const CabecalhoUsuario({
    super.key,
    required this.nome,
    this.subtitulo,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nome.isEmpty ? '?' : nome[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.ciano, Color.fromARGB(255, 25, 136, 139)],
            ),
          ),
          child: Text(
            inicial,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitulo == null)
                Text(
                  'Olá,',
                  style: GoogleFonts.poppins(
                    color: AppColors.gray,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AppColors.title,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitulo != null)
                Text(
                  subtitulo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.gray,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        ?acao,
      ],
    );
  }
}
