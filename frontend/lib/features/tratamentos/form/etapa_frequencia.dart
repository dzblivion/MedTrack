import 'package:flutter/material.dart';

import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';
import '../tratamento_validators.dart';
import 'aviso_info.dart';
import 'campos_frequencia.dart';
import 'rascunho_tratamento.dart';

/// Etapa 2: frequência, horários e data de início.
class EtapaFrequencia extends StatelessWidget {
  final RascunhoTratamento rascunho;
  final VoidCallback onMudou;

  const EtapaFrequencia({
    super.key,
    required this.rascunho,
    required this.onMudou,
  });

  @override
  Widget build(BuildContext context) {
    final r = rascunho;
    final porIntervalo = r.modo == ModoFrequencia.intervalo;

    // As chaves evitam que o Flutter confunda os campos quando a frequência
    // muda e campos aparecem ou somem no meio da lista.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown(
          key: const ValueKey('frequencia'),
          label: 'Frequência*',
          hint: 'Selecione a frequência',
          valor: r.modo?.name,
          opcoes: [for (final modo in ModoFrequencia.values) modo.name],
          rotulo: (nome) => ModoFrequencia.values.byName(nome).rotulo,
          validator: TratamentoValidators.escolha('Escolha a frequência'),
          onChanged: (nome) {
            if (nome == null) return;
            r.mudarModo(ModoFrequencia.values.byName(nome));
            onMudou();
          },
        ),
        if (porIntervalo) ...[
          const SizedBox(height: 14),
          Row(
            key: const ValueKey('intervalo'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Intervalo*',
                  hint: 'Ex: 8',
                  controller: r.intervalo,
                  keyboardType: TextInputType.number,
                  validator: TratamentoValidators.intervalo(
                    emDias: r.intervaloEmDias,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppDropdown(
                  label: '',
                  hint: 'Horas',
                  valor: r.intervaloEmDias ? 'dias' : 'horas',
                  opcoes: const ['horas', 'dias'],
                  rotulo: (valor) => valor == 'dias' ? 'Dias' : 'Horas',
                  onChanged: (valor) {
                    r.intervaloEmDias = valor == 'dias';
                    onMudou();
                  },
                ),
              ),
            ],
          ),
        ],
        if (r.modo == ModoFrequencia.semanal) ...[
          const SizedBox(height: 14),
          CampoDiasSemana(
            key: const ValueKey('dias'),
            dias: r.dias,
            onMudou: onMudou,
          ),
        ],
        const SizedBox(height: 14),
        CampoHorarios(
          key: const ValueKey('horarios'),
          rotulo: porIntervalo
              ? 'Horário da primeira dose*'
              : 'Horário das doses*',
          horarios: r.horarios,
          maximo: porIntervalo ? 1 : null,
          onMudou: onMudou,
        ),
        const SizedBox(height: 10),
        const AvisoInfo(
          key: ValueKey('dica-horarios'),
          'Você pode selecionar os horários fixos ou definir um intervalo, '
          'dependendo da sua frequência.',
        ),
        const SizedBox(height: 14),
        AppTextField(
          key: const ValueKey('data-inicio'),
          label: 'Data de início*',
          hint: 'Selecione a data',
          controller: r.dataInicioTexto,
          onTap: () => _escolherData(context),
        ),
        const SizedBox(height: 14),
        const AvisoInfo(
          key: ValueKey('dica-prescricao'),
          'Confira as informações na sua prescrição para cadastrar o '
          'tratamento corretamente.',
        ),
      ],
    );
  }

  Future<void> _escolherData(BuildContext context) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: rascunho.dataInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data de início',
    );
    if (escolhida == null) return;

    rascunho.mudarDataInicio(escolhida);
    onMudou();
  }
}
