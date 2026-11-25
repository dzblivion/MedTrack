import 'package:flutter/material.dart';

import '../../mia/medicamento_lido.dart';

const _amarelo = Color(0xFFFFF4D6);
const _marrom = Color(0xFF8A6100);

/// Caixa amarela no topo de cada etapa quando o formulário veio da MIA:
/// o que conferir e o texto original da receita.
class AvisoMia extends StatelessWidget {
  final MedicamentoLido lido;

  /// 0, 1 ou 2.
  final int etapa;

  const AvisoMia({super.key, required this.lido, required this.etapa});

  static const _camposDaEtapa1 = [
    'medicamento',
    'dosagem_valor',
    'dosagem_unidade',
    'quantidade_por_dose',
    'forma_consumo',
  ];

  @override
  Widget build(BuildContext context) {
    final linhas = switch (etapa) {
      0 => _etapaMedicamento(),
      1 => _comTextoDaReceita(
          lido.frequenciaTexto,
          entendeu: lido.frequenciaSugerida != null,
          oQue: 'a frequência',
          extra: lido.duvidoso('data_inicio')
              ? 'Confira também a data de início.'
              : null,
        ),
      _ => _comTextoDaReceita(
          lido.duracaoTexto,
          entendeu: lido.duracaoSugerida != null,
          oQue: 'a duração',
        ),
    };
    if (linhas.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: _amarelo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _marrom, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linha in linhas)
                  Text(
                    linha,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: _marrom,
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

  List<String> _etapaMedicamento() {
    final conferir = {
      for (final campo in _camposDaEtapa1)
        if (lido.duvidoso(campo)) ?_rotuloDe(campo),
    };
    return [
      'Preenchido pela MIA a partir da sua receita. '
          'A extração pode conter erros.',
      if (conferir.isNotEmpty) 'Confira com atenção: ${conferir.join(', ')}.',
    ];
  }

  List<String> _comTextoDaReceita(
    String? texto, {
    required bool entendeu,
    required String oQue,
    String? extra,
  }) {
    final temTexto = texto != null && texto.trim().isNotEmpty;
    return [
      if (temTexto) 'Na receita: "${texto.trim()}"',
      if (temTexto && !entendeu)
        'A MIA não conseguiu entender $oQue. Preencha abaixo.'
      else if (temTexto)
        'Preenchemos a partir disso. Confira abaixo.',
      ?extra,
    ];
  }

  static String? _rotuloDe(String campo) =>
      MedicamentoLido(camposDuvidosos: [campo]).rotulosDuvidosos.firstOrNull;
}
