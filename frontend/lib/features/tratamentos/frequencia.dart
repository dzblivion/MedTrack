import '../../core/formatos.dart';

/// O backend agenda as doses no horário de America/Fortaleza (UTC-3, sem
/// horário de verão). Mandamos a âncora nesse fuso para que "08:00" no app
/// seja 08:00 também lá.
const _fusoApi = '-03:00';

/// Tipos aceitos pelo backend ([api]) e como aparecem no app.
enum TipoFrequencia {
  diario('diario'),
  semanal('semanal'),
  intervaloHoras('intervalo_horas'),
  intervaloDias('intervalo_dias');

  final String api;

  const TipoFrequencia(this.api);

  bool get porIntervalo =>
      this == TipoFrequencia.intervaloHoras ||
      this == TipoFrequencia.intervaloDias;

  static TipoFrequencia doBackend(String valor) => values.firstWhere(
        (tipo) => tipo.api == valor,
        orElse: () => TipoFrequencia.diario,
      );
}

/// Dias no padrão do backend: 1 = segunda ... 7 = domingo.
const diasDaSemana = {
  1: 'Seg',
  2: 'Ter',
  3: 'Qua',
  4: 'Qui',
  5: 'Sex',
  6: 'Sáb',
  7: 'Dom',
};

/// Quando o remédio deve ser tomado.
class Frequencia {
  final TipoFrequencia tipo;

  /// "HH:MM". Diário e semanal: horários das doses. Por intervalo: só o
  /// horário da primeira dose (o resto o backend calcula).
  final List<String> horarios;

  /// Só na semanal.
  final List<int> diasSemana;

  /// Só por intervalo: de quantas em quantas horas (ou dias).
  final int? intervaloValor;

  const Frequencia({
    required this.tipo,
    this.horarios = const [],
    this.diasSemana = const [],
    this.intervaloValor,
  });

  /// Lê uma regra de `GET /tratamentos/{id}` (campo `frequencias`).
  /// Os horários vêm como "7:00:00" e a âncora como "2026-11-11T07:00:00".
  factory Frequencia.fromJson(Map<String, dynamic> json) {
    final tipo = TipoFrequencia.doBackend(json['tipo'] as String);
    return Frequencia(
      tipo: tipo,
      horarios: tipo.porIntervalo
          ? [?_horaDaAncora(json['ancora_em'] as String?)]
          : [
              for (final h in json['horarios'] as List? ?? const [])
                _hhmm(h as String),
            ],
      diasSemana: [
        for (final d in json['dias_semana'] as List? ?? const []) d as int,
      ],
      intervaloValor: json['intervalo_valor'] as int?,
    );
  }

  /// O backend exige que a âncora caia no mesmo dia de [dataInicio].
  /// Diário e semanal ancoram à meia-noite (vale o dia inteiro); por
  /// intervalo, a âncora é a primeira dose.
  Map<String, dynamic> toJson(DateTime dataInicio) {
    final porIntervalo = tipo.porIntervalo;
    final horaAncora = porIntervalo ? horarios.first : '00:00';
    return {
      'tipo': tipo.api,
      'ancora_em': '${formatarDataApi(dataInicio)}T$horaAncora:00$_fusoApi',
      'horarios': porIntervalo ? <String>[] : horarios,
      'dias_semana': tipo == TipoFrequencia.semanal ? diasSemana : <int>[],
      'intervalo_valor': porIntervalo ? intervaloValor : null,
    };
  }

  /// "Diário · 08:00, 20:00", "A cada 8 horas · início às 07:00"...
  String get descricao {
    final horas = horarios.join(', ');
    return switch (tipo) {
      TipoFrequencia.diario => 'Diário · $horas',
      TipoFrequencia.semanal =>
        '${diasSemana.map((d) => diasDaSemana[d]).join(', ')} · $horas',
      TipoFrequencia.intervaloHoras =>
        'A cada ${_plural(intervaloValor, 'hora', 'horas')} · início às $horas',
      TipoFrequencia.intervaloDias =>
        'A cada ${_plural(intervaloValor, 'dia', 'dias')} · às $horas',
    };
  }

  static String _plural(int? valor, String um, String varios) =>
      valor == 1 ? um : '$valor $varios';

  static String _hhmm(String texto) {
    final partes = texto.split(':');
    return '${partes[0].padLeft(2, '0')}:${partes[1]}';
  }

  static String? _horaDaAncora(String? ancora) {
    if (ancora == null) return null;
    final hora = RegExp(r'T(\d{1,2}):(\d{2})').firstMatch(ancora);
    return hora == null ? null : '${hora[1]!.padLeft(2, '0')}:${hora[2]}';
  }
}
