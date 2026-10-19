import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cabecalho_usuario.dart';
import '../auth/sessao_controller.dart';
import 'tratamento.dart';
import 'tratamentos_controller.dart';
import 'widgets/tratamento_card.dart';

class TratamentosScreen extends StatefulWidget {
  const TratamentosScreen({super.key});

  @override
  State<TratamentosScreen> createState() => _TratamentosScreenState();
}

class _TratamentosScreenState extends State<TratamentosScreen> {
  bool _verFinalizados = false;

  // As telas de cadastro e de detalhe devolvem true quando algo mudou.
  Future<void> _abrir(String rota) async {
    final controller = context.read<TratamentosController>();
    final mudou = await context.push<bool>(rota);
    if (mudou == true) await controller.carregar();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TratamentosController>();
    final nome = context.watch<SessaoController>().usuario?.nome ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoUsuario(
              nome: nome,
              acao: _BotaoNovo(onPressed: () => _abrir(Rotas.novoTratamento)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Meus tratamentos:',
              style: TextStyle(
                color: AppColors.title,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _Abas(
              verFinalizados: _verFinalizados,
              onChanged: (valor) => setState(() => _verFinalizados = valor),
            ),
            const SizedBox(height: 12),
            Expanded(child: _conteudo(controller)),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(TratamentosController controller) {
    if (controller.carregando && controller.erro == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.erro != null) {
      return _Aviso(
        texto: controller.erro!,
        acao: TextButton(
          onPressed: controller.carregar,
          child: const Text('Tentar de novo'),
        ),
      );
    }

    final lista =
        _verFinalizados ? controller.finalizados : controller.emAndamento;
    final hoje = DateTime.now();

    return RefreshIndicator(
      onRefresh: controller.carregar,
      child: lista.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 60),
                _Aviso(
                  texto: _verFinalizados
                      ? 'Nenhum tratamento finalizado.'
                      : 'Nenhum tratamento em andamento.\n'
                          'Toque em "+ Novo tratamento" para cadastrar.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, indice) {
                final Tratamento tratamento = lista[indice];
                return TratamentoCard(
                  tratamento: tratamento,
                  hoje: hoje,
                  onTap: () => _abrir(Rotas.tratamento(tratamento.id)),
                );
              },
            ),
    );
  }
}

class _BotaoNovo extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotaoNovo({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Novo tratamento'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ciano,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _Abas extends StatelessWidget {
  final bool verFinalizados;
  final ValueChanged<bool> onChanged;

  const _Abas({required this.verFinalizados, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _aba('Em andamento', ativa: !verFinalizados, valor: false),
        const SizedBox(width: 10),
        _aba('Finalizados', ativa: verFinalizados, valor: true),
      ],
    );
  }

  Widget _aba(String texto, {required bool ativa, required bool valor}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(valor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativa ? AppColors.ciano : AppColors.cianoClaro,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: ativa ? Colors.white : AppColors.darkCiano,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final Widget? acao;

  const _Aviso({required this.texto, this.acao});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          ?acao,
        ],
      ),
    );
  }
}
