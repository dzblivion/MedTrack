import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../doses/dose.dart';
import 'cartao.dart';

/// Todas as doses de hoje em ordem de horário: as registradas mostram o
/// resultado, as que já chegaram têm os botões e as futuras aguardam.
class CardDosesDoDia extends StatelessWidget {
  final List<Dose> doses;
  final DateTime agora;
  final bool registrando;
  final void Function(Dose dose, {required bool tomada}) onRegistrar;

  const CardDosesDoDia({
    super.key,
    required this.doses,
    required this.agora,
    required this.registrando,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_bulleted_rounded,
                color: AppColors.darkCiano,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text('Doses de hoje', style: estiloTituloCartao),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < doses.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.field),
            _LinhaDose(
              dose: doses[i],
              agora: agora,
              registrando: registrando,
              onRegistrar: ({required tomada}) =>
                  onRegistrar(doses[i], tomada: tomada),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaDose extends StatelessWidget {
  final Dose dose;
  final DateTime agora;
  final bool registrando;
  final void Function({required bool tomada}) onRegistrar;

  const _LinhaDose({
    required this.dose,
    required this.agora,
    required this.registrando,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    final atrasada = dose.atrasada(agora);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.horario,
                  style: GoogleFonts.poppins(
                    color: atrasada ? AppColors.error : AppColors.inputText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (atrasada)
                  Text(
                    'atrasada',
                    style: GoogleFonts.poppins(
                      color: AppColors.error,
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
                  style: GoogleFonts.poppins(
                    color: AppColors.inputText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  dose.detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.gray,
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
      case StatusDose.pendente when dose.podeRegistrar(agora):
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BotaoPequeno(
              texto: 'Tomei',
              cor: AppColors.ciano,
              onPressed: registrando ? null : () => onRegistrar(tomada: true),
            ),
            const SizedBox(width: 6),
            _BotaoPequeno(
              texto: 'Não',
              cor: AppColors.error,
              onPressed: registrando ? null : () => onRegistrar(tomada: false),
            ),
          ],
        );
      case StatusDose.pendente:
        return Text(
          'aguardando',
          style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 10),
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
            style: GoogleFonts.poppins(
              color: cor,
              fontSize: 10,
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
        textStyle: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(texto),
    );
  }
}
