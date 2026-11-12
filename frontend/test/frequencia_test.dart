import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/tratamentos/frequencia.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';

void main() {
  final inicio = DateTime(2026, 11, 11);

  test('lê a frequência do detalhe (horários como "7:00:00")', () {
    final t = Tratamento.fromJson({
      'id': 3,
      'medicamento': 'Amoxicilina',
      'dosagem_valor': null,
      'dosagem_unidade': null,
      'quantidade_por_dose': '1.00',
      'forma_consumo': 'oral',
      'data_inicio': '2026-11-11T00:00:00',
      'duracao_dias': 7,
      'status': 'ativo',
      'frequencias': [
        {
          'id': 1,
          'tipo': 'semanal',
          'intervalo_valor': null,
          'ancora_em': '2026-11-11T00:00:00',
          'ativo': 1,
          'horarios': ['7:00:00', '20:30:00'],
          'dias_semana': [1, 5],
        },
      ],
    });

    final f = t.frequencia!;
    expect(f.tipo, TipoFrequencia.semanal);
    expect(f.horarios, ['07:00', '20:30']);
    expect(f.diasSemana, [1, 5]);
    expect(f.descricao, 'Seg, Sex · 07:00, 20:30');
  });

  test('a lista (sem frequencias) continua funcionando', () {
    final t = Tratamento.fromJson({
      'id': 3,
      'medicamento': 'Amoxicilina',
      'quantidade_por_dose': '1.00',
      'forma_consumo': 'oral',
      'data_inicio': '2026-11-11T00:00:00',
      'duracao_dias': null,
      'status': 'ativo',
    });

    expect(t.frequencia, isNull);
  });

  test('por intervalo, o horário vem da âncora', () {
    final f = Frequencia.fromJson({
      'tipo': 'intervalo_horas',
      'intervalo_valor': 8,
      'ancora_em': '2026-11-11T06:00:00',
      'horarios': <String>[],
      'dias_semana': <int>[],
    });

    expect(f.horarios, ['06:00']);
    expect(f.descricao, 'A cada 8 horas · início às 06:00');
  });

  test('monta o formato que o backend espera', () {
    const diario = Frequencia(
      tipo: TipoFrequencia.diario,
      horarios: ['08:00', '20:00'],
    );
    expect(diario.toJson(inicio), {
      'tipo': 'diario',
      'ancora_em': '2026-11-11T00:00:00-03:00',
      'horarios': ['08:00', '20:00'],
      'dias_semana': <int>[],
      'intervalo_valor': null,
    });

    const aCada2Dias = Frequencia(
      tipo: TipoFrequencia.intervaloDias,
      horarios: ['09:30'],
      intervaloValor: 2,
    );
    expect(aCada2Dias.toJson(inicio), {
      'tipo': 'intervalo_dias',
      'ancora_em': '2026-11-11T09:30:00-03:00',
      'horarios': <String>[],
      'dias_semana': <int>[],
      'intervalo_valor': 2,
    });
    expect(aCada2Dias.descricao, 'A cada 2 dias · às 09:30');
  });
}
