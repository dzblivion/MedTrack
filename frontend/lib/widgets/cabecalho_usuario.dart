import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Avatar com a inicial + nome, no topo das abas do app (como no Figma).
class CabecalhoUsuario extends StatelessWidget {
  final String nome;
  final Widget? acao;

  const CabecalhoUsuario({super.key, required this.nome, this.acao});

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
              colors: [AppColors.ciano, AppColors.darkCiano],
            ),
          ),
          child: Text(
            inicial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.title,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?acao,
      ],
    );
  }
}
