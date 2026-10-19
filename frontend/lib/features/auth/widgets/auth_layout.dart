import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Estrutura comum das telas de autenticação: cabeçalho teal + painel branco.
///
/// Quando o conteúdo cabe na tela, o painel preenche o espaço restante
/// (como no login). Quando não cabe (ex.: cadastro de profissional, com
/// mais campos), a tela rola em vez de estourar.
class AuthLayout extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final double alturaCabecalho;
  final Widget child;

  /// Conteúdo opcional exibido no espaço vazio do cabeçalho (ex.: a marca
  /// do app no login). Fica centralizado abaixo do subtítulo.
  final Widget? marcaCabecalho;

  /// Mostra a seta de voltar no cabeçalho, no padrão das outras telas.
  final VoidCallback? onVoltar;

  const AuthLayout({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.alturaCabecalho = 0.39,
    this.marcaCabecalho,
    this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ciano,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _Cabecalho(
                        titulo: titulo,
                        subtitulo: subtitulo,
                        altura: constraints.maxHeight * alturaCabecalho,
                        marca: marcaCabecalho,
                        onVoltar: onVoltar,
                      ),
                      Expanded(child: _Painel(child: child)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final double altura;
  final Widget? marca;
  final VoidCallback? onVoltar;

  const _Cabecalho({
    required this.titulo,
    required this.subtitulo,
    required this.altura,
    this.marca,
    this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            // Com a seta, o título desce para não ficar ao lado dela.
            padding: EdgeInsets.fromLTRB(24, onVoltar == null ? 32 : 52, 24, 0),
            child: _textos(),
          ),
          if (onVoltar != null)
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Voltar',
                onPressed: onVoltar,
              ),
            ),
        ],
      ),
    );
  }

  Widget _textos() {
    return Column(
      children: [
        if (marca != null) ...[marca!, const SizedBox(height: 28)],
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 210,
          child: Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _Painel extends StatelessWidget {
  final Widget child;

  const _Painel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: child,
    );
  }
}
