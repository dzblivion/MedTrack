import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import 'textos_legais.dart';

/// Tela de leitura dos Termos de uso e da Política de privacidade.
class TextoLegalScreen extends StatelessWidget {
  final String titulo;
  final List<SecaoTexto> secoes;

  const TextoLegalScreen({
    super.key,
    required this.titulo,
    required this.secoes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkCiano,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            for (final secao in secoes) ...[
              Text(
                secao.titulo,
                style: const TextStyle(
                  color: AppColors.darkCiano,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                secao.texto,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}
