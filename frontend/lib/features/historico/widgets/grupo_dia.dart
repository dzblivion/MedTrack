import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../doses/dose.dart';
import '../../doses/widgets/linha_dose.dart';

/// Um dia do histórico: faixa com a data e o resumo, e as doses do dia.
class GrupoDia extends StatelessWidget {
  /// "Hoje – quinta, 19/11".
  final String rotulo;
  final List<Dose> doses;
  final DateTime agora;
  final bool registrando;

  /// Nulo para só ver as doses (ex.: o profissional).
  final void Function(Dose dose, {required bool tomada})? onRegistrar;

  const GrupoDia({
    super.key,
    required this.rotulo,
    required this.doses,
    required this.agora,
    this.registrando = false,
    this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    final tomadas = doses.where((d) => d.status == StatusDose.tomada).length;
    const estiloFaixa = TextStyle(
      fontFamily: 'Poppins',
      color: AppColors.darkCiano,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.cianoClaro,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(rotulo, style: estiloFaixa)),
                Text(
                  '$tomadas de ${doses.length} '
                  '${doses.length == 1 ? 'tomada' : 'tomadas'}',
                  style: estiloFaixa.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < doses.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.field),
                  LinhaDose(
                    dose: doses[i],
                    agora: agora,
                    registrando: registrando,
                    rotuloAtraso: 'não registrada',
                    onRegistrar: switch (onRegistrar) {
                      final registrar? => ({required tomada}) => registrar(
                        doses[i],
                        tomada: tomada,
                      ),
                      null => null,
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
