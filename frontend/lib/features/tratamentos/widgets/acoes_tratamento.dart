import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../tratamento.dart';

/// Ações permitidas pelo backend para cada status.
class AcoesTratamento extends StatelessWidget {
  final StatusTratamento status;
  final bool ocupado;
  final VoidCallback onEditar;
  final ValueChanged<StatusTratamento> onMudarStatus;
  final VoidCallback onCancelar;

  const AcoesTratamento({
    super.key,
    required this.status,
    required this.ocupado,
    required this.onEditar,
    required this.onMudarStatus,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    if (status == StatusTratamento.cancelado) {
      return const Text(
        'Este tratamento foi cancelado e não pode mais ser alterado.',
        style: TextStyle(color: AppColors.gray, fontSize: 12),
      );
    }

    final botoes = <Widget>[
      _botao('Editar', Icons.edit_outlined, onEditar),
      if (status == StatusTratamento.ativo)
        _botao(
          'Pausar',
          Icons.pause_circle_outline,
          () => onMudarStatus(StatusTratamento.pausado),
        ),
      if (status == StatusTratamento.pausado)
        _botao(
          'Retomar',
          Icons.play_circle_outline,
          () => onMudarStatus(StatusTratamento.ativo),
        ),
      if (status.emAndamento)
        _botao(
          'Concluir',
          Icons.check_circle_outline,
          () => onMudarStatus(StatusTratamento.concluido),
        ),
      if (status == StatusTratamento.concluido)
        _botao(
          'Reativar',
          Icons.replay,
          () => onMudarStatus(StatusTratamento.ativo),
        ),
      if (status.emAndamento)
        _botao(
          'Cancelar tratamento',
          Icons.cancel_outlined,
          onCancelar,
          cor: AppColors.error,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final botao in botoes)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: botao),
      ],
    );
  }

  Widget _botao(
    String texto,
    IconData icone,
    VoidCallback aoTocar, {
    Color cor = AppColors.darkCiano,
  }) {
    return OutlinedButton.icon(
      onPressed: ocupado ? null : aoTocar,
      icon: Icon(icone, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: cor,
        side: BorderSide(color: cor.withValues(alpha: 0.5)),
        minimumSize: const Size.fromHeight(42),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
