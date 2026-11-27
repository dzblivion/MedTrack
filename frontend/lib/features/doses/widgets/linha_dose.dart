import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../dose.dart';

/// Uma dose numa lista (Home e Histórico): horário, remédio e a situação.
/// Registrada mostra o selo; já chegou a hora mostra Tomei/Não; futura
/// mostra "aguardando".
class LinhaDose extends StatelessWidget {
  final Dose dose;
  final DateTime agora;
  final bool registrando;

  /// Nulo para só ver, sem os botões Tomei/Não (ex.: o profissional).
  final void Function({required bool tomada})? onRegistrar;

  /// Aviso em vermelho embaixo do horário quando a dose está atrasada
  /// ("atrasada" na Home, "não registrada" no Histórico).
  final String rotuloAtraso;

  const LinhaDose({
    super.key,
    required this.dose,
    required this.agora,
    required this.registrando,
    this.onRegistrar,
    this.rotuloAtraso = 'atrasada',
  });

  @override
  Widget build(BuildContext context) {
    final atrasada = dose.atrasada(agora);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.horario,
                  style: TextStyle(
                    color: atrasada ? AppColors.error : AppColors.inputText,
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (atrasada)
                  Text(
                    rotuloAtraso,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontFamily: 'Poppins',
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicamento,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  dose.detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.gray,
                    fontFamily: 'Poppins',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _situacao(),
        ],
      ),
    );
  }

  Widget _situacao() {
    final registrar = onRegistrar;
    switch (dose.status) {
      case StatusDose.tomada:
        return const _Selo(
          texto: 'Tomada',
          icone: Icons.check_rounded,
          cor: AppColors.darkCiano,
        );
      case StatusDose.naoTomada:
        return const _Selo(
          texto: 'Não tomada',
          icone: Icons.close_rounded,
          cor: AppColors.error,
        );
      case StatusDose.pendente
          when registrar != null && dose.podeRegistrar(agora):
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BotaoPequeno(
              texto: 'Tomei',
              cor: AppColors.ciano,
              onPressed: registrando ? null : () => registrar(tomada: true),
            ),
            const SizedBox(width: 6),
            _BotaoPequeno(
              texto: 'Não',
              cor: AppColors.error,
              onPressed: registrando ? null : () => registrar(tomada: false),
            ),
          ],
        );
      // Só leitura: a hora chegou e o paciente ainda não marcou.
      case StatusDose.pendente when dose.podeRegistrar(agora):
        return const SizedBox.shrink();
      case StatusDose.pendente:
        return const Text(
          'aguardando',
          style: TextStyle(
            color: AppColors.gray,
            fontFamily: 'Poppins',
            fontSize: 10,
          ),
        );
    }
  }
}

class _Selo extends StatelessWidget {
  final String texto;
  final IconData icone;
  final Color cor;

  const _Selo({required this.texto, required this.icone, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: cor),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 10,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoPequeno extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback? onPressed;

  const _BotaoPequeno({required this.texto, required this.cor, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: cor.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 26),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontSize: 10,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(texto),
    );
  }
}
