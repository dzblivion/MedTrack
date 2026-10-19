import '../../core/formatos.dart';

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

class Tratamento {
  final int id;
  final String medicamento;
  final double dosagemValor;
  final String dosagemUnidade;
  final double quantidadePorDose;
  final String formaConsumo;
  final DateTime dataInicio;
  final int duracaoDias;
  final StatusTratamento status;

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
  });

  // O backend manda os decimais como texto ("500.00") e a data com hora.
  factory Tratamento.fromJson(Map<String, dynamic> json) => Tratamento(
        id: json['id'] as int,
        medicamento: json['medicamento'] as String,
        dosagemValor: double.parse(json['dosagem_valor'].toString()),
        dosagemUnidade: json['dosagem_unidade'] as String,
        quantidadePorDose: double.parse(json['quantidade_por_dose'].toString()),
        formaConsumo: json['forma_consumo'] as String,
        dataInicio: _soData(DateTime.parse(json['data_inicio'] as String)),
        duracaoDias: json['duracao_dias'] as int,
        status: StatusTratamento.doBackend(json['status'] as String),
      );

  DateTime get dataFim => dataInicio.add(Duration(days: duracaoDias - 1));

  /// Dia do tratamento em que estamos: 0 antes de começar, até a duração total.
  int diaAtual(DateTime hoje) {
    final dias = _soData(hoje).difference(dataInicio).inDays + 1;
    return dias.clamp(0, duracaoDias);
  }

  bool periodoEncerrado(DateTime hoje) => _soData(hoje).isAfter(dataFim);

  /// "500 mg · 1 por dose · oral".
  String get resumoDosagem {
    final forma = formasConsumo[formaConsumo]?.toLowerCase() ?? formaConsumo;
    return '${formatarNumero(dosagemValor)} ${_unidadeExibida()} · '
        '${formatarNumero(quantidadePorDose)} por dose · $forma';
  }

  String _unidadeExibida() => switch (dosagemUnidade) {
        'ui' => 'UI',
        'gota' => dosagemValor == 1 ? 'gota' : 'gotas',
        _ => dosagemUnidade,
      };

  static DateTime _soData(DateTime data) =>
      DateTime(data.year, data.month, data.day);
}
