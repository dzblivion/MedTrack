import '../../core/formatos.dart';
import 'tratamento.dart';

/// O que o formulário envia para cadastrar ou editar um tratamento.
class DadosTratamento {
  final String medicamento;
  final double dosagemValor;
  final String dosagemUnidade;
  final double quantidadePorDose;
  final String formaConsumo;
  final DateTime dataInicio;
  final int duracaoDias;

  const DadosTratamento({
    required this.medicamento,
    required this.dosagemValor,
    required this.dosagemUnidade,
    required this.quantidadePorDose,
    required this.formaConsumo,
    required this.dataInicio,
    required this.duracaoDias,
  });

  factory DadosTratamento.de(Tratamento t) => DadosTratamento(
        medicamento: t.medicamento,
        dosagemValor: t.dosagemValor,
        dosagemUnidade: t.dosagemUnidade,
        quantidadePorDose: t.quantidadePorDose,
        formaConsumo: t.formaConsumo,
        dataInicio: t.dataInicio,
        duracaoDias: t.duracaoDias,
      );

  Map<String, dynamic> toJson() => {
        'medicamento': medicamento,
        'dosagem_valor': dosagemValor,
        'dosagem_unidade': dosagemUnidade,
        'quantidade_por_dose': quantidadePorDose,
        'forma_consumo': formaConsumo,
        'data_inicio': formatarDataApi(dataInicio),
        'duracao_dias': duracaoDias,
      };
}
