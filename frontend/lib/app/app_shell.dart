import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Estrutura do app logado: a aba aberta + o menu inferior do protótipo.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navegacao;

  const AppShell({super.key, required this.navegacao});

  static const _itens = [
    (icone: Icons.home_outlined, rotulo: 'Início'),
    (icone: Icons.medication_outlined, rotulo: 'Tratamentos'),
    (icone: Icons.assignment_outlined, rotulo: 'Histórico'),
    (icone: Icons.account_circle_outlined, rotulo: 'Perfil'),
  ];

  void _abrir(int indice) {
    // Tocar na aba já aberta volta para o começo dela.
    navegacao.goBranch(
      indice,
      initialLocation: indice == navegacao.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navegacao,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.ciano,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _itens.length; i++)
                Expanded(
                  child: _ItemMenu(
                    icone: _itens[i].icone,
                    rotulo: _itens[i].rotulo,
                    ativo: i == navegacao.currentIndex,
                    onTap: () => _abrir(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icone,
    required this.rotulo,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 24,
            child: ativo
                // O item ativo "sobe" num círculo acima da barra, como no Figma.
                // Ocupa o espaço de um ícone comum; só é desenhado maior.
                ? OverflowBox(
                    maxWidth: 48,
                    maxHeight: 48,
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.ciano,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 4,
                          ),
                        ),
                        child: Icon(icone, color: Colors.white, size: 24),
                      ),
                    ),
                  )
                : Icon(icone, color: Colors.white, size: 22),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              rotulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
