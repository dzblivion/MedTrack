import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/compartilhamento/pacientes_controller.dart';
import '../features/compartilhamento/pedidos_controller.dart';
import '../features/historico/historico_controller.dart';
import '../features/home/home_controller.dart';
import '../theme/app_theme.dart';

typedef _Item = ({IconData icone, String rotulo, int aba});

/// Estrutura do app logado: a aba aberta + o menu inferior do protótipo.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navegacao;

  /// O profissional só tem "Pacientes" (no lugar do Início) e "Perfil".
  final bool profissional;

  const AppShell({
    super.key,
    required this.navegacao,
    this.profissional = false,
  });

  static const _inicio = 0;
  static const _historico = 2;
  static const _perfil = 3;

  static const List<_Item> _itensPaciente = [
    (icone: Icons.home_outlined, rotulo: 'Início', aba: _inicio),
    (icone: Icons.medication_outlined, rotulo: 'Tratamentos', aba: 1),
    (icone: Icons.assignment_outlined, rotulo: 'Histórico', aba: _historico),
    (icone: Icons.account_circle_outlined, rotulo: 'Perfil', aba: _perfil),
  ];

  static const List<_Item> _itensProfissional = [
    (icone: Icons.groups_outlined, rotulo: 'Pacientes', aba: _inicio),
    (icone: Icons.account_circle_outlined, rotulo: 'Perfil', aba: _perfil),
  ];

  void _abrir(BuildContext context, int aba) {
    // Abrir o Início ou o Histórico sempre traz os dados atualizados
    // (ex.: uma dose marcada numa aba aparece na outra).
    if (aba == _inicio && profissional) {
      context.read<PacientesController>().carregar();
    } else if (aba == _inicio) {
      context.read<HomeController>().carregar();
      context.read<PedidosController>().carregar();
    }
    if (aba == _historico) context.read<HistoricoController>().carregar();

    // Tocar na aba já aberta volta para o começo dela.
    navegacao.goBranch(aba, initialLocation: aba == navegacao.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final itens = profissional ? _itensProfissional : _itensPaciente;

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
              for (final item in itens)
                Expanded(
                  child: _ItemMenu(
                    icone: item.icone,
                    rotulo: item.rotulo,
                    ativo: item.aba == navegacao.currentIndex,
                    onTap: () => _abrir(context, item.aba),
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
