import 'package:flutter/material.dart';

import '../../../core/formatos.dart';
import '../../../theme/app_theme.dart';
import '../tratamento.dart';

class TratamentoCard extends StatelessWidget {
  final Tratamento tratamento;
  final DateTime hoje;
  final VoidCallback onTap;

  const TratamentoCard({
    super.key,
    required this.tratamento,
    required this.hoje,
    required this.onTap,
  });

  static const _corStatus = {
    StatusTratamento.ativo: AppColors.ciano,
    StatusTratamento.pausado: Color(0xFFE0A800),
    StatusTratamento.concluido: AppColors.darkCiano,
    StatusTratamento.cancelado: AppColors.error,
  };

  String get _andamento {
    final t = tratamento;
    if (!t.status.emAndamento) return '${t.duracaoDias} dias';
    if (t.periodoEncerrado(hoje)) return 'período encerrado';

    final dia = t.diaAtual(hoje);
    if (dia == 0) return 'começa em ${formatarDiaMes(t.dataInicio)}';
    return '$dia de ${t.duracaoDias} dias';
  }

  @override
  Widget build(BuildContext context) {
    final t = tratamento;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medication_outlined,
                    color: AppColors.ciano,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.medicamento,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkCiano,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.darkCiano),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.resumoDosagem,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.darkCiano,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${formatarDiaMes(t.dataInicio)} - '
                    '${formatarDiaMes(t.dataFim)}',
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _corStatus[t.status],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.status.rotulo,
                    style: const TextStyle(color: AppColors.gray, fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    _andamento,
                    style: const TextStyle(color: AppColors.gray, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
