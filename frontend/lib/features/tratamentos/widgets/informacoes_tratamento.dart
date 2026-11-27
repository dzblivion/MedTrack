import 'package:flutter/material.dart';

import '../../../core/formatos.dart';
import '../../../theme/app_theme.dart';
import '../tratamento.dart';

/// Quadro com os dados do tratamento (dosagem, frequência, período...).
/// Usado no detalhe do paciente e no do profissional.
class InformacoesTratamento extends StatelessWidget {
  final Tratamento tratamento;

  const InformacoesTratamento({super.key, required this.tratamento});

  List<(String, String)> _itens(DateTime hoje) {
    final t = tratamento;
    final fim = t.dataFim;
    final duracao = t.duracaoDias;
    final emCurso = t.status.emAndamento && !t.periodoEncerrado(hoje);
    final progresso = switch (duracao) {
      null when emCurso && t.diaAtual(hoje) > 0 =>
        'uso contínuo · dia ${t.diaAtual(hoje)}',
      null => 'uso contínuo',
      _ when emCurso => 'dia ${t.diaAtual(hoje)} de $duracao',
      _ => '$duracao dias',
    };
    final periodo = fim == null
        ? 'desde ${formatarData(t.dataInicio)}'
        : '${formatarData(t.dataInicio)} a ${formatarData(fim)}';

    return [
      ('Dosagem', t.dosagem ?? 'não informada'),
      ('Quantidade por dose', formatarNumero(t.quantidadePorDose)),
      ('Forma de consumo', formasConsumo[t.formaConsumo] ?? t.formaConsumo),
      // Só tratamentos de antes da frequência ser obrigatória ficam sem.
      ('Frequência', t.frequencia?.descricao ?? 'não cadastrada'),
      ('Período', periodo),
      ('Duração', progresso),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          for (final (rotulo, valor) in _itens(DateTime.now()))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rotulo,
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      valor,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
