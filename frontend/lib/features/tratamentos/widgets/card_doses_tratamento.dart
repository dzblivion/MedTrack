import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../doses/resumo_doses.dart';

const _fonte = 'Poppins';

/// Bloco "Doses" do detalhe: tomadas sobre o total e as perdidas em
/// destaque, com o atalho para conferir no Histórico.
class CardDosesTratamento extends StatelessWidget {
  /// Nulo enquanto carrega.
  final ResumoDoses? resumo;
  final bool usoContinuo;

  /// As doses não carregaram (o resto do detalhe continua funcionando).
  final bool falhou;
  final VoidCallback onVerHistorico;
  final VoidCallback onTentarDeNovo;

  const CardDosesTratamento({
    super.key,
    required this.resumo,
    required this.usoContinuo,
    required this.falhou,
    required this.onVerHistorico,
    required this.onTentarDeNovo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Doses',
            style: TextStyle(
              fontFamily: _fonte,
              color: AppColors.darkCiano,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._conteudo(),
        ],
      ),
    );
  }

  List<Widget> _conteudo() {
    final r = resumo;
    if (falhou) {
      return [
        const Text(
          'Não foi possível carregar as doses.',
          style: TextStyle(fontFamily: _fonte, color: AppColors.gray, fontSize: 12),
        ),
        TextButton(onPressed: onTentarDeNovo, child: const Text('Tentar de novo')),
      ];
    }
    if (r == null) {
      return const [
        Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ];
    }
    if (r.total == 0) {
      return const [
        Text(
          'Nenhuma dose agendada para este tratamento.',
          style: TextStyle(fontFamily: _fonte, color: AppColors.gray, fontSize: 12),
        ),
      ];
    }

    const pequeno = TextStyle(fontFamily: _fonte, color: AppColors.gray, fontSize: 11);
    return [
      // O contínuo só tem as próximas semanas criadas: não há total.
      if (usoContinuo)
        Text(
          '${r.tomadas} ${r.tomadas == 1 ? 'dose tomada' : 'doses tomadas'} '
          'até agora',
          style: _destaque,
        )
      else ...[
        Text('${r.tomadas} de ${r.total} doses tomadas', style: _destaque),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: r.fracaoTomadas,
            minHeight: 10,
            backgroundColor: AppColors.field,
            color: AppColors.ciano,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(r.fracaoTomadas * 100).round()}%', style: pequeno),
        ),
      ],
      const SizedBox(height: 6),
      Text(
        '✓ ${r.tomadas} ${r.tomadas == 1 ? 'tomada' : 'tomadas'}   ·   '
        '${r.restantes} ${r.restantes == 1 ? 'restante' : 'restantes'}',
        style: pequeno,
      ),
      if (r.comecou) ...[
        const SizedBox(height: 12),
        _AreaPerdidas(resumo: r, onVerHistorico: onVerHistorico),
      ],
    ];
  }

  static const _destaque = TextStyle(
    fontFamily: _fonte,
    color: AppColors.inputText,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
}

class _AreaPerdidas extends StatelessWidget {
  final ResumoDoses resumo;
  final VoidCallback onVerHistorico;

  const _AreaPerdidas({required this.resumo, required this.onVerHistorico});

  @override
  Widget build(BuildContext context) {
    final perdidas = resumo.perdidas;
    final cor = perdidas > 0 ? AppColors.error : AppColors.darkCiano;
    final detalhes = [
      if (resumo.naoTomadas > 0)
        '${resumo.naoTomadas} ${resumo.naoTomadas == 1 ? 'não tomada' : 'não tomadas'}',
      if (resumo.semRegistro > 0) '${resumo.semRegistro} sem registro',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                perdidas > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: cor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  perdidas > 0
                      ? '$perdidas ${perdidas == 1 ? 'dose não tomada' : 'doses não tomadas'}'
                      : 'Nenhuma dose perdida',
                  style: TextStyle(
                    fontFamily: _fonte,
                    color: cor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (detalhes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                detalhes,
                style: const TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.gray,
                  fontSize: 11,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onVerHistorico,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('Ver no histórico'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkCiano,
                textStyle: const TextStyle(
                  fontFamily: _fonte,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
