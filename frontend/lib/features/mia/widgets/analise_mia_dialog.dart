import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// O que a pessoa escolheu na janela "Análise com a MIA".
enum EscolhaAnalise { anuncio, plus, manual }

/// Janela depois da foto: assistir a um anúncio para ganhar a análise,
/// conhecer o Plus ou cadastrar à mão. Nulo = cancelou.
Future<EscolhaAnalise?> mostrarAnaliseMia(BuildContext context) =>
    showDialog<EscolhaAnalise>(
      context: context,
      builder: (_) => const _AnaliseMiaDialog(),
    );

class _AnaliseMiaDialog extends StatelessWidget {
  const _AnaliseMiaDialog();

  static const _fonte = 'Poppins';

  @override
  Widget build(BuildContext context) {
    void escolher(EscolhaAnalise escolha) => Navigator.of(context).pop(escolha);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.cianoClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.darkCiano,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.title,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(text: 'Análise com a '),
                  TextSpan(
                    text: 'MIA',
                    style: TextStyle(color: AppColors.ciano),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Assista a um anúncio para ganhar uma análise com a MIA.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fonte,
                color: AppColors.gray,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => escolher(EscolhaAnalise.anuncio),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ciano,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: _fonte,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Assistir anúncio'),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: AppColors.cianoClaro,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.ciano),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => escolher(EscolhaAnalise.plus),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.darkCiano,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conheça o MedTrack Plus',
                              style: TextStyle(
                                fontFamily: _fonte,
                                color: AppColors.darkCiano,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Digitalize sem assistir a anúncios →',
                              style: TextStyle(
                                fontFamily: _fonte,
                                color: AppColors.darkCiano,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => escolher(EscolhaAnalise.manual),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.gray,
                  textStyle: const TextStyle(fontFamily: _fonte, fontSize: 11),
                ),
                child: const Text('Cadastrar manualmente'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray,
                textStyle: const TextStyle(fontFamily: _fonte, fontSize: 11),
              ),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
