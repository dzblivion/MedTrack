import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';

/// Apresentação do plano pago. Só visual por enquanto: não há cobrança.
class PlusScreen extends StatelessWidget {
  const PlusScreen({super.key});

  static const _fonte = 'Poppins';

  static const _beneficios = [
    (Icons.document_scanner_outlined, 'MIA sem anúncios',
        'Digitalize quantas receitas quiser, sem esperar.'),
    (Icons.picture_as_pdf_outlined, 'Relatório de adesão',
        'Leve ao médico um resumo das doses tomadas.'),
    (Icons.family_restroom_outlined, 'Cuide da família',
        'Acompanhe os tratamentos de quem você ama.'),
    (Icons.notifications_active_outlined, 'Lembretes avançados',
        'Repetição e alertas para quem esqueceu a dose.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkCiano,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.ciano,
              size: 64,
            ),
            const SizedBox(height: 8),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.title,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(text: 'MedTrack '),
                  TextSpan(
                    text: 'Plus',
                    style: TextStyle(color: AppColors.ciano),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Mais cuidado, menos preocupação.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fonte,
                color: AppColors.gray,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            for (final (icone, titulo, descricao) in _beneficios)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cianoClaro,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icone, color: AppColors.darkCiano),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontFamily: _fonte,
                              color: AppColors.inputText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            descricao,
                            style: const TextStyle(
                              fontFamily: _fonte,
                              color: AppColors.gray,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ciano, width: 1.5),
              ),
              child: const Column(
                children: [
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontFamily: _fonte,
                        color: AppColors.darkCiano,
                      ),
                      children: [
                        TextSpan(
                          text: 'R\$ 9,90',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: ' /mês', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  Text(
                    '7 dias grátis para experimentar',
                    style: TextStyle(
                      fontFamily: _fonte,
                      color: AppColors.gray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              // Só visual: a assinatura ainda não existe.
              onPressed: () =>
                  AppSnackBar.info(context, 'A assinatura chega em breve!'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ciano,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: _fonte,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Assinar o Plus'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Em breve. Nenhuma cobrança é feita agora.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fonte,
                color: AppColors.gray,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
