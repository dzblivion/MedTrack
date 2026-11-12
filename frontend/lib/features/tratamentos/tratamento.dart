import '../../core/formatos.dart';
import 'frequencia.dart';

enum StatusTratamento {
  ativo('em andamento'),
  pausado('pausado'),
  concluido('concluído'),
  cancelado('cancelado');

  final String rotulo;

  const StatusTratamento(this.rotulo);

  static StatusTratamento doBackend(String valor) => values.firstWhere(
        (status) => status.name == valor,
        orElse: () => StatusTratamento.ativo,
      );

  /// Aba "Em andamento"; os demais vão para "Finalizados".
  bool get emAndamento =>
      this == StatusTratamento.ativo || this == StatusTratamento.pausado;
}

/// Valores aceitos pelo backend e como aparecem no app.
const unidadesDosagem = {
  'mg': 'mg',
  'mcg': 'mcg',
  'g': 'g',
  'ml': 'ml',
  'ui': 'UI',
  'gota': 'gota(s)',
};

/// Valores aceitos pelo backend (sem acento) e como aparecem no app.
const formasConsumo = {
  'oral': 'Oral',
  'sublingual': 'Sublingual',
  'topica': 'Tópica',
  'injetavel': 'Injetável',
  'inalatoria': 'Inalatória',
  'oftalmica': 'Oftálmica',
  'nasal': 'Nasal',
  'retal': 'Retal',
  'vaginal': 'Vaginal',
  'outra': 'Outra',
};

/// "500 mg", "20 gotas", "1 gota", "10 UI".
String formatarDosagem(double valor, String? unidade) {
  final exibida = switch (unidade) {
    'ui' => 'UI',
    'gota' => valor == 1 ? 'gota' : 'gotas',
    final outra => outra ?? '',
  };
  return '${formatarNumero(valor)} $exibida';
}

class Tratamento {
  final int id;
  final String medicamento;

  /// Dosagem e duração são opcionais no backend (ex.: receita sem dosagem).
  final double? dosagemValor;
  final String? dosagemUnidade;
  final double quantidadePorDose;
  final String formaConsumo;
  final DateTime dataInicio;

  /// Sem duração = uso contínuo.
  final int? duracaoDias;
  final StatusTratamento status;

  /// Só vem no detalhe (`GET /tratamentos/{id}`); a lista não traz.
  final Frequencia? frequencia;

  const Tratamento({
    required this.id,
    required this.medicamento,
    required this.dosagemValor,
    required this.dosagemUnidade,
    required this.quantidadePorDose,
    required this.formaConsumo,
    required this.dataInicio,
    required this.duracaoDias,
    required this.status,
    this.frequencia,
  });

  // O backend manda os decimais como texto ("500.00") e a data com hora.
  factory Tratamento.fromJson(Map<String, dynamic> json) => Tratamento(
        id: json['id'] as int,
        medicamento: json['medicamento'] as String,
        dosagemValor: _decimal(json['dosagem_valor']),
        dosagemUnidade: json['dosagem_unidade'] as String?,
        quantidadePorDose: _decimal(json['quantidade_por_dose']) ?? 1,
        formaConsumo: json['forma_consumo'] as String? ?? 'outra',
        dataInicio: _soData(DateTime.parse(json['data_inicio'] as String)),
        duracaoDias: json['duracao_dias'] as int?,
        status: StatusTratamento.doBackend(json['status'] as String),
        frequencia: _frequenciaAtiva(json['frequencias']),
      );

  /// O backend guarda uma lista de regras; o tratamento usa a ativa.
  static Frequencia? _frequenciaAtiva(Object? regras) {
    if (regras is! List || regras.isEmpty) return null;
    final lista = regras.cast<Map<String, dynamic>>();
    final ativa = lista.firstWhere(
      (regra) => regra['ativo'] == true || regra['ativo'] == 1,
      orElse: () => lista.first,
    );
    return Frequencia.fromJson(ativa);
  }

  bool get usoContinuo => duracaoDias == null;

  /// Último dia do tratamento; nulo no uso contínuo.
  DateTime? get dataFim {
    final dias = duracaoDias;
    return dias == null ? null : dataInicio.add(Duration(days: dias - 1));
  }

  /// Dia do tratamento em que estamos: 0 antes de começar. Com duração,
  /// para no último dia.
  int diaAtual(DateTime hoje) {
    final dias = _soData(hoje).difference(dataInicio).inDays + 1;
    if (dias < 0) return 0;
    final total = duracaoDias;
    return total == null ? dias : dias.clamp(0, total);
  }

  bool periodoEncerrado(DateTime hoje) {
    final fim = dataFim;
    return fim != null && _soData(hoje).isAfter(fim);
  }

  /// "500 mg", ou nulo quando a dosagem não foi informada.
  String? get dosagem {
    final valor = dosagemValor;
    return valor == null ? null : formatarDosagem(valor, dosagemUnidade);
  }

  /// "500 mg · 1 por dose · oral" (sem a dosagem, quando não informada).
  String get resumoDosagem {
    final forma = formasConsumo[formaConsumo]?.toLowerCase() ?? formaConsumo;
    return [
      ?dosagem,
      '${formatarNumero(quantidadePorDose)} por dose',
      forma,
    ].join(' · ');
  }

  static double? _decimal(Object? valor) =>
      valor == null ? null : double.parse(valor.toString());

  static DateTime _soData(DateTime data) =>
      DateTime(data.year, data.month, data.day);
}
