import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../doses/dose.dart';
import 'cartao.dart';

/// Próxima dose com os botões "Já tomei" e "Não tomei".
class CardProximaDose extends StatelessWidget {
  /// Nula quando não há dose pendente hoje.
  final Dose? dose;
  final DateTime agora;

  /// Diferencia "nada agendado" de "tudo registrado".
  final bool semDoses;
  final bool registrando;
  final void Function({required bool tomada}) onRegistrar;

  const CardProximaDose({
    super.key,
    required this.dose,
    required this.agora,
    required this.semDoses,
    required this.registrando,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    final dose = this.dose;

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.darkCiano,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text('Próxima dose', style: estiloTituloCartao),
            ],
          ),
          const SizedBox(height: 10),
          if (dose == null)
            Text(
              semDoses
                  ? 'Nenhuma dose agendada para hoje.'
                  : 'Todas as doses de hoje foram registradas.',
              style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 12),
            )
          else
            ..._dose(dose),
        ],
      ),
    );
  }

  List<Widget> _dose(Dose dose) {
    final liberada = dose.podeRegistrar(agora) && !registrando;
    return [
      Row(
        children: [
          Text(
            dose.horario,
            style: GoogleFonts.poppins(
              color: AppColors.ciano,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dose.atrasada(agora)) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'atrasada',
                style: GoogleFonts.poppins(
                  color: AppColors.error,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      Text(
        dose.medicamento,
        style: GoogleFonts.poppins(
          color: AppColors.inputText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        dose.detalhe,
        style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 10),
      ),
      const SizedBox(height: 12),
      // O backend recusa registrar antes do horário.
      if (!dose.podeRegistrar(agora))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Você poderá registrar a partir das ${dose.horario}.',
            style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 10),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: _Botao(
              texto: 'Já tomei',
              cor: AppColors.ciano,
              onPressed: liberada ? () => onRegistrar(tomada: true) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Botao(
              texto: 'Não tomei',
              cor: AppColors.error,
              onPressed: liberada ? () => onRegistrar(tomada: false) : null,
            ),
          ),
        ],
      ),
    ];
  }
}

class _Botao extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback? onPressed;

  const _Botao({required this.texto, required this.cor, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: cor.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(texto),
    );
  }
}
