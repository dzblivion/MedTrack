import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/doses/dose.dart';

import 'helpers.dart';

/// Bloco "Doses" no detalhe do tratamento e o atalho para o Histórico.
void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<void> abrirDetalhe(
    WidgetTester tester, {
    required TratamentoFake tratamentos,
    required DoseFake doses,
    int id = 1,
  }) =>
      abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        tratamentos: tratamentos,
        doses: doses,
        rota: Rotas.tratamento(id),
      );

  DateTime haHoras(int horas) =>
      DateTime.now().subtract(Duration(hours: horas));
  DateTime daquiHoras(int horas) => DateTime.now().add(Duration(hours: horas));

  testWidgets('mostra tomadas sobre o total e as perdidas em destaque', (
    tester,
  ) async {
    await abrirDetalhe(
      tester,
      tratamentos: TratamentoFake([tratamentoExemplo(diasAtras: 2)]),
      doses: DoseFake([
        doseExemplo(id: 1, em: haHoras(30), status: StatusDose.tomada),
        doseExemplo(id: 2, em: haHoras(20), status: StatusDose.tomada),
        doseExemplo(id: 3, em: haHoras(10), status: StatusDose.tomada),
        doseExemplo(id: 4, em: haHoras(5), status: StatusDose.naoTomada),
        doseExemplo(id: 5, em: haHoras(1)),
        doseExemplo(id: 6, em: daquiHoras(5)),
        doseExemplo(id: 7, em: daquiHoras(10)),
        // Outro tratamento: não entra na conta.
        doseExemplo(id: 8, tratamentoId: 2, em: haHoras(2)),
      ]),
    );

    await tester.ensureVisible(find.text('Doses'));
    expect(find.text('3 de 7 doses tomadas'), findsOneWidget);
    expect(find.text('43%'), findsOneWidget);
    expect(find.text('2 doses não tomadas'), findsOneWidget);
    expect(find.text('1 não tomada · 1 sem registro'), findsOneWidget);
    expect(find.text('Ver no histórico'), findsOneWidget);
  });

  testWidgets('uso contínuo mostra só as tomadas até agora, sem total', (
    tester,
  ) async {
    await abrirDetalhe(
      tester,
      tratamentos: TratamentoFake([tratamentoExemplo(continuo: true)]),
      doses: DoseFake([
        doseExemplo(id: 1, em: haHoras(20), status: StatusDose.tomada),
        doseExemplo(id: 2, em: haHoras(10), status: StatusDose.tomada),
        doseExemplo(id: 3, em: daquiHoras(4)),
      ]),
    );

    await tester.ensureVisible(find.text('Doses'));
    expect(find.text('2 doses tomadas até agora'), findsOneWidget);
    expect(find.textContaining('doses tomadas', findRichText: true),
        findsOneWidget);
    expect(find.text('Nenhuma dose perdida'), findsOneWidget);
  });

  testWidgets('antes da primeira dose não mostra a área de perdidas', (
    tester,
  ) async {
    await abrirDetalhe(
      tester,
      tratamentos: TratamentoFake([tratamentoExemplo(diasAtras: -1)]),
      doses: DoseFake([doseExemplo(em: daquiHoras(30))]),
    );

    await tester.ensureVisible(find.text('Doses'));
    expect(find.text('0 de 1 doses tomadas'), findsOneWidget);
    expect(find.text('Nenhuma dose perdida'), findsNothing);
    expect(find.text('Ver no histórico'), findsNothing);
  });

  testWidgets('se as doses falharem, o resto do detalhe continua', (
    tester,
  ) async {
    final doses = DoseFake([
      doseExemplo(em: haHoras(2), status: StatusDose.tomada),
    ])..erroDoTratamento = const ApiException('erro');
    await abrirDetalhe(
      tester,
      tratamentos: TratamentoFake([tratamentoExemplo()]),
      doses: doses,
    );

    expect(find.text('Amoxicilina'), findsOneWidget);
    await tester.ensureVisible(find.text('Não foi possível carregar as doses.'));

    await tocar(tester, 'Tentar de novo');
    expect(find.text('1 de 1 doses tomadas'), findsOneWidget);
  });

  testWidgets('Ver no histórico abre só as doses daquele tratamento', (
    tester,
  ) async {
    final agora = DateTime.now();
    // Bem perto de agora, para cair no mês atual.
    final pouco = agora.subtract(const Duration(minutes: 3));
    await abrirDetalhe(
      tester,
      tratamentos: TratamentoFake([
        tratamentoExemplo(id: 1, medicamento: 'Losartana'),
        tratamentoExemplo(id: 2, medicamento: 'Outro'),
      ]),
      doses: DoseFake([
        doseExemplo(
          id: 1,
          medicamento: 'Losartana',
          em: pouco,
          status: StatusDose.naoTomada,
        ),
        doseExemplo(
          id: 2,
          tratamentoId: 2,
          medicamento: 'Outro',
          em: pouco,
          status: StatusDose.tomada,
        ),
      ]),
    );

    await tocar(tester, 'Ver no histórico');

    // Abre por cima do detalhe, sem o menu de baixo.
    expect(find.text('Histórico do tratamento'), findsOneWidget);
    expect(find.text('Seu histórico:'), findsNothing);
    expect(find.text('Início'), findsNothing);
    // O nome no título e na linha da dose; o outro tratamento não aparece.
    expect(find.text('Losartana'), findsNWidgets(2));
    expect(find.text('Outro'), findsNothing);

    // A seta volta para o detalhe.
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Histórico do tratamento'), findsNothing);
    expect(find.text('Doses'), findsOneWidget);
  });

  testWidgets('registrar no histórico atualiza a contagem ao voltar', (
    tester,
  ) async {
    final esquecida = DateTime.now().subtract(const Duration(minutes: 30));
    await abrirDetalhe(
      tester,
      tratamentos: TratamentoFake([tratamentoExemplo()]),
      doses: DoseFake([doseExemplo(id: 5, em: esquecida)]),
    );

    await tester.ensureVisible(find.text('Doses'));
    expect(find.text('0 de 1 doses tomadas'), findsOneWidget);
    expect(find.text('1 dose não tomada'), findsOneWidget);

    await tocar(tester, 'Ver no histórico');
    await tocar(tester, 'Tomei');
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Doses'));
    expect(find.text('1 de 1 doses tomadas'), findsOneWidget);
    expect(find.text('Nenhuma dose perdida'), findsOneWidget);
  });

  testWidgets('a aba Histórico continua mostrando todos os tratamentos', (
    tester,
  ) async {
    final pouco = DateTime.now().subtract(const Duration(minutes: 3));
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      doses: DoseFake([
        doseExemplo(id: 1, medicamento: 'Losartana', em: pouco,
            status: StatusDose.tomada),
        doseExemplo(id: 2, tratamentoId: 2, medicamento: 'Outro', em: pouco,
            status: StatusDose.tomada),
      ]),
      rota: Rotas.historico,
    );

    expect(find.text('Losartana'), findsOneWidget);
    expect(find.text('Outro'), findsOneWidget);
  });

  testWidgets('histórico de um tratamento que acabou abre no mês dele', (
    tester,
  ) async {
    final agora = DateTime.now();
    final mesPassado = DateTime(agora.year, agora.month - 1, 12, 9);
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      doses: DoseFake([
        doseExemplo(
          id: 1,
          tratamentoId: 4,
          medicamento: 'Antigo',
          em: mesPassado,
          status: StatusDose.tomada,
        ),
      ]),
      rota: Rotas.historicoDoTratamento(4),
    );

    expect(find.text('Antigo'), findsNWidgets(2));
    expect(find.text('Tomada'), findsOneWidget);
  });
}
