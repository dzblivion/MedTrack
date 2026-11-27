import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/botao_cabecalho.dart';
import '../../widgets/cabecalho_usuario.dart';
import '../auth/sessao_controller.dart';
import '../tratamentos/widgets/tratamento_card.dart';
import 'pacientes_controller.dart';

/// Início do profissional: os pacientes que compartilharam tratamentos.
class PacientesScreen extends StatelessWidget {
  const PacientesScreen({super.key});

  Future<void> _adicionar(BuildContext context) async {
    final controller = context.read<PacientesController>();
    await context.push(Rotas.adicionarPaciente);
    // O paciente pode ter aprovado enquanto isso.
    await controller.carregar();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PacientesController>();
    final nome = context.watch<SessaoController>().usuario?.nome ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoUsuario(
              nome: nome,
              acao: BotaoCabecalho(
                texto: 'Adicionar paciente',
                onPressed: () => _adicionar(context),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              'Meus pacientes:',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.title,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: _conteudo(context, controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context, PacientesController controller) {
    if (controller.erro != null) {
      return [
        const SizedBox(height: 40),
        Text(
          controller.erro!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gray, fontSize: 13),
        ),
        Center(
          child: TextButton(
            onPressed: controller.carregar,
            child: const Text('Tentar de novo'),
          ),
        ),
      ];
    }
    if (controller.carregando && controller.vazio) {
      return const [
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (controller.vazio) {
      return const [
        SizedBox(height: 60),
        Text(
          'Nenhum paciente ainda.\n'
          'Peça ao paciente o código de compartilhamento e toque em '
          '"+ Adicionar paciente".',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.gray, fontSize: 13),
        ),
      ];
    }

    final hoje = DateTime.now();
    return [
      for (final (:nome, :tratamentos) in controller.pacientes) ...[
        _NomePaciente(nome: nome),
        for (final item in tratamentos) ...[
          TratamentoCard(
            tratamento: item.tratamento,
            hoje: hoje,
            onTap: () => context.push(
              Rotas.tratamentoDePaciente(item.compartilhamentoId),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _NomePaciente extends StatelessWidget {
  final String nome;

  const _NomePaciente({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.cianoClaro,
            child: Text(
              nome.isEmpty ? '?' : nome[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.darkCiano,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
