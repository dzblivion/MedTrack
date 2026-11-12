import '../../core/formatos.dart';
import 'frequencia.dart';

/// O que o formulário envia para cadastrar ou editar um tratamento.
class DadosTratamento {
  final String medicamento;
  final double? dosagemValor;
  final String? dosagemUnidade;
  final double quantidadePorDose;
  final String formaConsumo;
  final DateTime dataInicio;

  /// Nulo = uso contínuo.
  final int? duracaoDias;

  /// O backend exige a frequência para gerar as doses.
  final Frequencia frequencia;

  const DadosTratamento({
    required this.medicamento,
    required this.dosagemValor,
    required this.dosagemUnidade,
    required this.quantidadePorDose,
    required this.formaConsumo,
    required this.dataInicio,
    required this.duracaoDias,
    required this.frequencia,
  });

  Map<String, dynamic> toJson() => {
        'medicamento': medicamento,
        'dosagem_valor': dosagemValor,
        // O backend recusa unidade sem valor.
        'dosagem_unidade': dosagemValor == null ? null : dosagemUnidade,
        'quantidade_por_dose': quantidadePorDose,
        'forma_consumo': formaConsumo,
        'data_inicio': formatarDataApi(dataInicio),
        'duracao_dias': duracaoDias,
        'frequencia': frequencia.toJson(dataInicio),
      };
}
