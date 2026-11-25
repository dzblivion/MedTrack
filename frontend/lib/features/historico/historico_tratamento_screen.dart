import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import 'historico_controller.dart';
import 'widgets/lista_historico.dart';

/// Histórico de um tratamento, aberto por cima do detalhe ("Ver no
/// histórico"). A seta volta para o detalhe, avisando se alguma dose foi
/// registrada aqui (para ele atualizar a contagem).
class HistoricoTratamentoScreen extends StatefulWidget {
  /// Nome para o título; sem ele (ex.: página recarregada), usa o das doses.
  final String? medicamento;

  const HistoricoTratamentoScreen({super.key, this.medicamento});

  @override
  State<HistoricoTratamentoScreen> createState() =>
      _HistoricoTratamentoScreenState();
}

class _HistoricoTratamentoScreenState extends State<HistoricoTratamentoScreen> {
  bool _registrou = false;

  void _voltar() => context.pop(_registrou);

  @override
  Widget build(BuildContext context) {
    final nome =
        widget.medicamento ?? context.watch<HistoricoController>().nomeDoFiltro;

    // Também cobre o "voltar" do celular, para o detalhe saber se mudou.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _voltar();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.darkCiano,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
            onPressed: _voltar,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Histórico do tratamento',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (nome != null)
                Text(
                  nome,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.gray,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ListaHistorico(onRegistrou: () => _registrou = true),
          ),
        ),
      ),
    );
  }
}
