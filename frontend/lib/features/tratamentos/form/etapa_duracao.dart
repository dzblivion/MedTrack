import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_text_field.dart';
import '../tratamento_validators.dart';
import 'aviso_info.dart';
import 'rascunho_tratamento.dart';

/// Etapa 3: com data de término ou contínuo, e o resumo antes de salvar.
class EtapaDuracao extends StatelessWidget {
  final RascunhoTratamento rascunho;
  final VoidCallback onMudou;

  const EtapaDuracao({
    super.key,
    required this.rascunho,
    required this.onMudou,
  });

  @override
  Widget build(BuildContext context) {
    final r = rascunho;
    final rotulo = GoogleFonts.poppins(
      color: AppColors.inputText,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    void escolherContinuo(bool continuo) {
      r.continuo = continuo;
      r.atualizarTermino();
      onMudou();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duração do tratamento*', style: rotulo),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: _OpcaoDuracao(
                titulo: 'Com data de término',
                descricao: 'Informe quantos dias o tratamento deve durar.',
                ativa: !r.continuo,
                onTap: () => escolherContinuo(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OpcaoDuracao(
                titulo: 'Contínuo',
                descricao: 'Sem data de término.',
                ativa: r.continuo,
                onTap: () => escolherContinuo(true),
              ),
            ),
          ],
        ),
        if (!r.continuo) ...[
          const SizedBox(height: 14),
          AppTextField(
            key: const ValueKey('duracao'),
            label: 'Duração (dias)*',
            hint: 'Ex: 7',
            controller: r.duracao,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: TratamentoValidators.duracao,
            onChanged: (_) {
              r.atualizarTermino();
              onMudou();
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            key: const ValueKey('termino'),
            label: 'Data de término (opcional)',
            hint: 'Selecione a data',
            controller: r.termino,
            onTap: () => _escolherTermino(context),
          ),
        ],
        const SizedBox(height: 14),
        Text('Resumo do tratamento', style: rotulo),
        const SizedBox(height: 5),
        _Resumo(itens: r.resumo),
        const SizedBox(height: 14),
        const AvisoInfo(
          'Após salvar, o tratamento aparecerá na sua lista de tratamentos e '
          'os lembretes serão criados conforme as informações cadastradas.',
        ),
      ],
    );
  }

  Future<void> _escolherTermino(BuildContext context) async {
    final inicio = rascunho.dataInicio;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: rascunho.dataTermino ?? inicio,
      firstDate: inicio,
      lastDate: DateTime(
        inicio.year,
        inicio.month,
        inicio.day + TratamentoValidators.limiteDuracao - 1,
      ),
      helpText: 'Data de término',
    );
    if (escolhida == null) return;

    rascunho.mudarTermino(escolhida);
    onMudou();
  }
}

class _OpcaoDuracao extends StatelessWidget {
  final String titulo;
  final String descricao;
  final bool ativa;
  final VoidCallback onTap;

  const _OpcaoDuracao({
    required this.titulo,
    required this.descricao,
    required this.ativa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = ativa ? Colors.white : AppColors.darkCiano;
    return Material(
      color: ativa ? AppColors.ciano : AppColors.cianoClaro,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: GoogleFonts.poppins(
                  color: cor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                descricao,
                style: GoogleFonts.poppins(color: cor, fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  final List<(String, String)> itens;

  const _Resumo({required this.itens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final (rotulo, valor) in itens)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: GoogleFonts.poppins(
                      color: AppColors.darkCiano,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    valor,
                    style: GoogleFonts.poppins(
                      color: AppColors.gray,
                      fontSize: 10,
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
