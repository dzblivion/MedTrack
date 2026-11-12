import 'package:flutter/material.dart';

import '../../../core/formatos.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';
import '../tratamento.dart';
import '../tratamento_validators.dart';
import 'aviso_info.dart';
import 'rascunho_tratamento.dart';

/// Etapa 1: nome, forma de consumo, dosagem e quantidade por dose.
class EtapaMedicamento extends StatelessWidget {
  final RascunhoTratamento rascunho;
  final VoidCallback onMudou;

  const EtapaMedicamento({
    super.key,
    required this.rascunho,
    required this.onMudou,
  });

  @override
  Widget build(BuildContext context) {
    final r = rascunho;
    const numero = TextInputType.numberWithOptions(decimal: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Nome do medicamento*',
          hint: 'Ex: Paracetamol',
          controller: r.medicamento,
          textInputAction: TextInputAction.next,
          validator: TratamentoValidators.medicamento,
        ),
        const SizedBox(height: 14),
        AppDropdown(
          label: 'Forma de consumo*',
          hint: 'Selecione uma opção',
          valor: r.forma,
          opcoes: formasConsumo.keys.toList(),
          rotulo: (valor) => formasConsumo[valor]!,
          validator: TratamentoValidators.escolha('Escolha a forma de consumo'),
          onChanged: (valor) {
            r.forma = valor;
            onMudou();
          },
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                label: 'Dosagem',
                hint: 'Valor',
                controller: r.dosagem,
                keyboardType: numero,
                validator: TratamentoValidators.numeroPositivo(
                  'a dosagem',
                  obrigatorio: false,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppDropdown(
                label: '',
                hint: 'Unidade',
                valor: r.unidade,
                opcoes: unidadesDosagem.keys.toList(),
                rotulo: (valor) => unidadesDosagem[valor]!,
                // Só é obrigatória quando a dosagem foi preenchida.
                validator: (valor) =>
                    valor == null && lerNumero(r.dosagem.text) != null
                        ? 'Escolha a unidade'
                        : null,
                onChanged: (valor) {
                  r.unidade = valor;
                  onMudou();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Quantidade por dose*',
          hint: 'Ex: 1 comprimido',
          controller: r.quantidade,
          keyboardType: numero,
          textInputAction: TextInputAction.done,
          validator: TratamentoValidators.numeroPositivo('a quantidade'),
        ),
        const SizedBox(height: 18),
        const AvisoInfo(
          'Confira as informações na sua prescrição para cadastrar o '
          'tratamento corretamente.',
        ),
      ],
    );
  }
}
