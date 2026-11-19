import 'package:flutter/material.dart';

import '../../../core/formatos.dart';
import '../../../theme/app_theme.dart';

/// "‹ Novembro de 2026 ›": troca o mês mostrado no histórico.
class SeletorMes extends StatelessWidget {
  final DateTime mes;
  final VoidCallback? onAnterior;
  final VoidCallback? onProximo;

  const SeletorMes({
    super.key,
    required this.mes,
    required this.onAnterior,
    required this.onProximo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _Seta(
            icone: Icons.chevron_left_rounded,
            dica: 'Mês anterior',
            onPressed: onAnterior,
          ),
          Expanded(
            child: Text(
              formatarMesAno(mes),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.darkCiano,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _Seta(
            icone: Icons.chevron_right_rounded,
            dica: 'Próximo mês',
            onPressed: onProximo,
          ),
        ],
      ),
    );
  }
}

class _Seta extends StatelessWidget {
  final IconData icone;
  final String dica;
  final VoidCallback? onPressed;

  const _Seta({required this.icone, required this.dica, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icone),
      tooltip: dica,
      onPressed: onPressed,
      color: AppColors.darkCiano,
      disabledColor: AppColors.field,
    );
  }
}
