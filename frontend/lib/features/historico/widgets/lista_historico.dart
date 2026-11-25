import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_snackbar.dart';
import '../../doses/dose.dart';
import '../historico_controller.dart';
import 'grupo_dia.dart';
import 'seletor_mes.dart';

/// Seletor de mês + dias com as doses. Usado pela aba Histórico e pelo
/// histórico de um tratamento (cada um com o seu [HistoricoController]).
class ListaHistorico extends StatelessWidget {
  /// Chamado depois de registrar uma dose (ex.: o detalhe atualizar a
  /// contagem ao voltar).
  final VoidCallback? onRegistrou;

  const ListaHistorico({super.key, this.onRegistrou});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HistoricoController>();

    return Column(
      children: [
        SeletorMes(
          mes: controller.mes,
          onAnterior: controller.podeVoltar ? controller.mesAnterior : null,
          onProximo: controller.podeAvancar ? controller.proximoMes : null,
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
    );
  }

  List<Widget> _conteudo(BuildContext context, HistoricoController controller) {
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

    final dias = controller.dias;
    if (controller.carregando && dias.isEmpty) {
      return const [
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (dias.isEmpty) {
      return [
        const SizedBox(height: 60),
        Text(
          'Nenhuma dose em ${nomeDoMes(controller.mes)}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gray, fontSize: 13),
        ),
      ];
    }

    return [
      for (final (:dia, :doses) in dias) ...[
        GrupoDia(
          rotulo: controller.rotuloDoDia(dia),
          doses: doses,
          agora: controller.agora,
          registrando: controller.registrando != null,
          onRegistrar: (dose, {required tomada}) =>
              _registrar(context, controller, dose, tomada: tomada),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Future<void> _registrar(
    BuildContext context,
    HistoricoController controller,
    Dose dose, {
    required bool tomada,
  }) async {
    try {
      await controller.registrar(dose, tomada: tomada);
      onRegistrou?.call();
      if (context.mounted) {
        AppSnackBar.info(
          context,
          tomada
              ? 'Dose registrada como tomada.'
              : 'Dose registrada como não tomada.',
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    }
  }
}
