import '../tratamentos/frequencia.dart';
import '../tratamentos/tratamento.dart';
import 'interpretar_receita.dart';

/// Um medicamento que a MIA leu na receita, ainda sem salvar. Vira a
/// sugestão do formulário, que a pessoa confere antes de cadastrar.
class MedicamentoLido {
  final String? medicamento;
  final double? dosagemValor;

  /// Já no formato do backend ("mg", "gota"...) ou nulo se não reconhecida.
  final String? dosagemUnidade;
  final double? quantidadePorDose;

  /// Já padronizada pelo backend ("oral", "topica"...) ou nula.
  final String? formaConsumo;

  /// Como está escrito na receita ("de 8 em 8 horas").
  final String? frequenciaTexto;
  final String? duracaoTexto;
  final DateTime? dataInicio;

  /// Campos que a MIA não leu com segurança (nomes do backend).
  final List<String> camposDuvidosos;

  const MedicamentoLido({
    this.medicamento,
    this.dosagemValor,
    this.dosagemUnidade,
    this.quantidadePorDose,
    this.formaConsumo,
    this.frequenciaTexto,
    this.duracaoTexto,
    this.dataInicio,
    this.camposDuvidosos = const [],
  });

  factory MedicamentoLido.fromJson(Map<String, dynamic> json) {
    final duvidosos = [
      for (final campo in json['campos_duvidosos'] as List? ?? const [])
        '$campo',
    ];
    final unidadeBruta = json['dosagem_unidade'] as String?;
    final unidade = _unidade(unidadeBruta);
    // Unidade que existe na receita mas o app não reconhece: pede conferência.
    if (unidadeBruta != null && unidade == null) duvidosos.add('dosagem_unidade');

    final forma = json['forma_consumo'] as String?;
    return MedicamentoLido(
      medicamento: (json['medicamento'] as String?)?.trim(),
      dosagemValor: _numero(json['dosagem_valor']),
      dosagemUnidade: unidade,
      quantidadePorDose: _numero(json['quantidade_por_dose']),
      formaConsumo: formasConsumo.containsKey(forma) ? forma : null,
      frequenciaTexto: json['frequencia_texto'] as String?,
      duracaoTexto: json['duracao_texto'] as String?,
      dataInicio: DateTime.tryParse('${json['data_inicio'] ?? ''}'),
      camposDuvidosos: duvidosos,
    );
  }

  Frequencia? get frequenciaSugerida => interpretarFrequencia(frequenciaTexto);
  DuracaoLida? get duracaoSugerida => interpretarDuracao(duracaoTexto);

  bool duvidoso(String campo) => camposDuvidosos.contains(campo);

  /// Nomes dos campos duvidosos para mostrar à pessoa.
  List<String> get rotulosDuvidosos => {
        for (final campo in camposDuvidosos) ?_rotulos[campo],
      }.toList();

  static const _rotulos = {
    'medicamento': 'nome do medicamento',
    'dosagem_valor': 'dosagem',
    'dosagem_unidade': 'unidade da dosagem',
    'quantidade_por_dose': 'quantidade por dose',
    'forma_consumo': 'forma de consumo',
    'frequencia_texto': 'frequência',
    'duracao_texto': 'duração',
    'data_inicio': 'data de início',
  };

  static double? _numero(Object? valor) =>
      valor == null ? null : double.tryParse('$valor'.replaceAll(',', '.'));

  /// "ML" → "ml", "gotas" → "gota", "µg" → "mcg"; desconhecida → nula.
  static String? _unidade(String? valor) {
    if (valor == null) return null;
    final u = valor.trim().toLowerCase();
    final normalizada = switch (u) {
      'gotas' || 'gts' || 'gt' => 'gota',
      'µg' || 'ug' || 'microgramas' => 'mcg',
      'mililitros' => 'ml',
      'miligramas' => 'mg',
      'gramas' => 'g',
      _ => u,
    };
    return unidadesDosagem.containsKey(normalizada) ? normalizada : null;
  }
}

/// Resposta de `POST /tratamentos/ler-prescricao`.
class ResultadoMia {
  final String textoExtraido;
  final List<MedicamentoLido> medicamentos;

  const ResultadoMia({required this.textoExtraido, required this.medicamentos});

  factory ResultadoMia.fromJson(Map<String, dynamic> json) {
    final dados = json['dados'] as Map<String, dynamic>? ?? const {};
    return ResultadoMia(
      textoExtraido: json['texto_extraido'] as String? ?? '',
      medicamentos: [
        for (final item in dados['medicamentos'] as List? ?? const [])
          MedicamentoLido.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}
