import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/formatos.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';

void main() {
  // Formato que a API devolve hoje (decimais como texto, data com hora).
  final json = {
    'id': 3,
    'medicamento': 'Amoxicilina',
    'dosagem_valor': '500.00',
    'dosagem_unidade': 'mg',
    'quantidade_por_dose': '1.00',
    'forma_consumo': 'oral',
    'data_inicio': '2026-10-05T00:00:00',
    'duracao_dias': 7,
    'status': 'ativo',
    'criado_em': '2026-10-05T14:27:37',
  };

  test('lê o formato da API', () {
    final t = Tratamento.fromJson(json);

    expect(t.dosagemValor, 500);
    expect(t.quantidadePorDose, 1);
    expect(t.dataInicio, DateTime(2026, 10, 5));
    expect(t.status, StatusTratamento.ativo);
  });

  test('monta o texto do card', () {
    expect(Tratamento.fromJson(json).resumoDosagem, '500 mg · 1 por dose · oral');

    final gotas = Tratamento.fromJson({
      ...json,
      'dosagem_valor': '20.00',
      'dosagem_unidade': 'gota',
      'quantidade_por_dose': '0.50',
      'forma_consumo': 'topica',
    });
    expect(gotas.resumoDosagem, '20 gotas · 0,5 por dose · tópica');
  });

  test('calcula o período e o dia atual', () {
    final t = Tratamento.fromJson(json);

    expect(t.dataFim, DateTime(2026, 10, 11));
    expect(t.diaAtual(DateTime(2026, 10, 4)), 0);
    expect(t.diaAtual(DateTime(2026, 10, 7, 22, 30)), 3);
    expect(t.diaAtual(DateTime(2026, 10, 20)), 7);
    expect(t.periodoEncerrado(DateTime(2026, 10, 11)), isFalse);
    expect(t.periodoEncerrado(DateTime(2026, 10, 12)), isTrue);
  });

  test('separa os status entre as abas', () {
    expect(StatusTratamento.ativo.emAndamento, isTrue);
    expect(StatusTratamento.pausado.emAndamento, isTrue);
    expect(StatusTratamento.concluido.emAndamento, isFalse);
    expect(StatusTratamento.cancelado.emAndamento, isFalse);
  });

  test('formata números e datas no padrão brasileiro', () {
    expect(formatarNumero(500), '500');
    expect(formatarNumero(0.5), '0,5');
    expect(formatarNumero(2.25), '2,25');
    expect(formatarDiaMes(DateTime(2026, 3, 7)), '07/03');
  });
}
