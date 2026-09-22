import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Estrutura comum das telas de autenticação: cabeçalho teal + painel branco.
class AuthLayout extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final double alturaCabecalho;
  final Widget child;

  const AuthLayout({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.alturaCabecalho = 0.39,
  });

  @override
  Widget build(BuildContext context) {
    final alturaTela = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: AppColors.ciano,
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                _Cabecalho(
                  titulo: titulo,
                  subtitulo: subtitulo,
                  altura: alturaTela * alturaCabecalho,
                ),
                Expanded(child: _Painel(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final double altura;

  const _Cabecalho({
    required this.titulo,
    required this.subtitulo,
    required this.altura,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Column(
            children: [
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
          ),
        ),
      ),
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
