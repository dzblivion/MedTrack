import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<void> abrirTratamentos(
    WidgetTester tester,
    TratamentoFake tratamentos,
  ) =>
      abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        tratamentos: tratamentos,
        rota: Rotas.tratamentos,
      );

  testWidgets('mostra os tratamentos em andamento com o resumo', (
    tester,
  ) async {
    await abrirTratamentos(
      tester,
      TratamentoFake([tratamentoExemplo(diasAtras: 2)]),
    );

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('500 mg · 1 por dose · oral'), findsOneWidget);
    expect(find.text('em andamento'), findsOneWidget);
    expect(find.text('3 de 7 dias'), findsOneWidget);
  });

  testWidgets('separa Em andamento e Finalizados pelo status', (tester) async {
    await abrirTratamentos(
      tester,
      TratamentoFake([
        tratamentoExemplo(id: 1, medicamento: 'Ativo'),
        tratamentoExemplo(
          id: 2,
          medicamento: 'Pausado',
          status: StatusTratamento.pausado,
        ),
        tratamentoExemplo(
          id: 3,
          medicamento: 'Concluido',
          status: StatusTratamento.concluido,
        ),
        tratamentoExemplo(
          id: 4,
          medicamento: 'Cancelado',
          status: StatusTratamento.cancelado,
        ),
      ]),
    );

    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Pausado'), findsOneWidget);
    expect(find.text('Concluido'), findsNothing);

    await tocar(tester, 'Finalizados');

    expect(find.text('Concluido'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Ativo'), findsNothing);
  });

  testWidgets('ativo com o período já terminado continua em andamento', (
    tester,
  ) async {
    await abrirTratamentos(
      tester,
      TratamentoFake([tratamentoExemplo(diasAtras: 10)]),
    );

    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('período encerrado'), findsOneWidget);
  });

  testWidgets('tratamento que ainda não começou mostra a data de início', (
    tester,
  ) async {
    await abrirTratamentos(
      tester,
      TratamentoFake([tratamentoExemplo(diasAtras: -3)]),
    );

    expect(find.textContaining('começa em'), findsOneWidget);
  });

  testWidgets('sem tratamentos, mostra o aviso', (tester) async {
    await abrirTratamentos(tester, TratamentoFake());

    expect(find.textContaining('Nenhum tratamento em andamento'), findsOneWidget);
  });

  testWidgets('erro da API mostra a mensagem e permite tentar de novo', (
    tester,
  ) async {
    final tratamentos = TratamentoFake([tratamentoExemplo()])
      ..erro = const ApiException('Não foi possível conectar ao servidor.');
    await abrirTratamentos(tester, tratamentos);

    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);

    await tocar(tester, 'Tentar de novo');

    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(tratamentos.buscas, 2);
  });

  testWidgets('o botão de novo tratamento e o card abrem as próximas telas', (
    tester,
  ) async {
    await abrirTratamentos(tester, TratamentoFake([tratamentoExemplo()]));

    await tocar(tester, 'Novo tratamento');
    expect(find.text('Salvar tratamento'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe do tratamento'), findsOneWidget);
  });
}
