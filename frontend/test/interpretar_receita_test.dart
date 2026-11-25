import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/mia/interpretar_receita.dart';
import 'package:frontend/features/mia/medicamento_lido.dart';
import 'package:frontend/features/tratamentos/frequencia.dart';

void main() {
  group('frequência', () {
    void intervaloHoras(String texto, int horas) {
      final f = interpretarFrequencia(texto);
      expect(f?.tipo, TipoFrequencia.intervaloHoras, reason: texto);
      expect(f?.intervaloValor, horas, reason: texto);
      expect(f?.horarios, ['08:00'], reason: texto);
    }

    void diario(String texto, List<String> horarios) {
      final f = interpretarFrequencia(texto);
      expect(f?.tipo, TipoFrequencia.diario, reason: texto);
      expect(f?.horarios, horarios, reason: texto);
    }

    test('intervalos em horas', () {
      intervaloHoras('de 8 em 8 horas', 8);
      intervaloHoras('Tomar de 12/12h', 12);
      intervaloHoras('8/8 h', 8);
      intervaloHoras('a cada 6 horas', 6);
      intervaloHoras('De seis em seis horas', 6);
    });

    test('vezes ao dia viram horários sugeridos', () {
      diario('1 vez ao dia', ['08:00']);
      diario('uma vez ao dia', ['08:00']);
      diario('2x ao dia', ['08:00', '20:00']);
      diario('três vezes ao dia', ['08:00', '14:00', '20:00']);
      diario('4 vezes por dia', ['08:00', '12:00', '16:00', '20:00']);
      diario('diariamente', ['08:00']);
      diario('de 24 em 24 horas', ['08:00']);
    });

    test('6 vezes ao dia vira a cada 4 horas', () {
      intervaloHoras('6 vezes ao dia', 4);
    });

    test('intervalo em dias', () {
      final f = interpretarFrequencia('a cada 2 dias');
      expect(f?.tipo, TipoFrequencia.intervaloDias);
      expect(f?.intervaloValor, 2);
    });

    test('o que não entende fica em branco', () {
      expect(interpretarFrequencia(null), isNull);
      expect(interpretarFrequencia(''), isNull);
      expect(interpretarFrequencia('se tiver dor'), isNull);
    });
  });

  group('duração', () {
    test('dias, semanas e meses', () {
      expect(interpretarDuracao('por 7 dias'), (dias: 7, continuo: false));
      expect(interpretarDuracao('durante 2 semanas'), (dias: 14, continuo: false));
      expect(interpretarDuracao('por um mês'), (dias: 30, continuo: false));
      expect(interpretarDuracao('por dez dias'), (dias: 10, continuo: false));
    });

    test('uso contínuo', () {
      expect(interpretarDuracao('uso contínuo'), (dias: null, continuo: true));
      expect(interpretarDuracao('Tempo indeterminado'), (dias: null, continuo: true));
    });

    test('o que não entende fica em branco', () {
      expect(interpretarDuracao(null), isNull);
      expect(interpretarDuracao('até melhorar'), isNull);
    });
  });

  group('resposta da MIA', () {
    test('lê o formato do backend e padroniza a unidade', () {
      final r = ResultadoMia.fromJson({
        'texto_extraido': 'Amoxicilina 500 mg...',
        'dados': {
          'medicamentos': [
            {
              'medicamento': ' Amoxicilina ',
              'dosagem_valor': 500,
              'dosagem_unidade': 'MG',
              'quantidade_por_dose': 1,
              'forma_consumo': 'oral',
              'frequencia_texto': 'de 8 em 8 horas',
              'duracao_texto': 'por 7 dias',
              'data_inicio': null,
              'campos_duvidosos': ['quantidade_por_dose'],
            },
            {
              'medicamento': 'Colírio X',
              'dosagem_valor': 2,
              'dosagem_unidade': 'gotas',
              'quantidade_por_dose': null,
              'forma_consumo': null,
              'frequencia_texto': null,
              'duracao_texto': null,
              'data_inicio': '2026-11-20',
              'campos_duvidosos': ['forma_consumo'],
            },
          ],
        },
      });

      expect(r.medicamentos, hasLength(2));
      final a = r.medicamentos.first;
      expect(a.medicamento, 'Amoxicilina');
      expect(a.dosagemValor, 500);
      expect(a.dosagemUnidade, 'mg');
      expect(a.frequenciaSugerida?.intervaloValor, 8);
      expect(a.duracaoSugerida, (dias: 7, continuo: false));
      expect(a.rotulosDuvidosos, ['quantidade por dose']);

      final b = r.medicamentos.last;
      expect(b.dosagemUnidade, 'gota');
      expect(b.dataInicio, DateTime(2026, 11, 20));
      expect(b.rotulosDuvidosos, ['forma de consumo']);
    });

    test('unidade desconhecida fica vazia e vira campo para conferir', () {
      final m = MedicamentoLido.fromJson({
        'medicamento': 'X',
        'dosagem_unidade': 'comprimidos',
        'campos_duvidosos': [],
      });

      expect(m.dosagemUnidade, isNull);
      expect(m.rotulosDuvidosos, ['unidade da dosagem']);
    });
  });
}
