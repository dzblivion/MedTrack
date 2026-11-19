import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../doses/dose.dart';
import '../../doses/widgets/linha_dose.dart';
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
            LinhaDose(
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
