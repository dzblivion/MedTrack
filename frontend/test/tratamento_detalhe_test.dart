import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/formatos.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<void> abrirDetalhe(
    WidgetTester tester,
    TratamentoFake tratamentos, {
    String? rota,
  }) async {
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      tratamentos: tratamentos,
      rota: rota ?? Rotas.tratamentos,
    );
    if (rota == null) {
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
    }
  }

  Future<void> voltar(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os dados do tratamento', (tester) async {
    final t = tratamentoExemplo(diasAtras: 2);
    await abrirDetalhe(tester, TratamentoFake([t]));

    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('500 mg'), findsOneWidget);
    expect(find.text('Oral'), findsOneWidget);
    expect(
      find.text('${formatarData(t.dataInicio)} a ${formatarData(t.dataFim)}'),
      findsOneWidget,
    );
    expect(find.text('dia 3 de 7'), findsOneWidget);
  });

  testWidgets('ativo: pausar troca para Retomar e a lista recarrega ao voltar', (
    tester,
  ) async {
    final tratamentos = TratamentoFake([tratamentoExemplo()]);
    await abrirDetalhe(tester, tratamentos);

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
    expect(find.text('Retomar'), findsNothing);

    await tocar(tester, 'Pausar');

    expect(tratamentos.mudancasStatus, [StatusTratamento.pausado]);
    expect(find.text('Tratamento pausado.'), findsOneWidget);
    expect(find.text('Retomar'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);

    final buscasAntes = tratamentos.buscas;
    await voltar(tester);

    expect(find.text('Meus tratamentos:'), findsOneWidget);
    expect(tratamentos.buscas, buscasAntes + 1);
  });

  testWidgets('cancelar pede confirmação e depois bloqueia a edição', (
    tester,
  ) async {
    final tratamentos = TratamentoFake([tratamentoExemplo()]);
    await abrirDetalhe(tester, tratamentos);

    await tocar(tester, 'Cancelar tratamento');
    expect(find.text('Cancelar tratamento?'), findsOneWidget);

    await tocar(tester, 'Voltar');
    expect(tratamentos.cancelamentos, 0);

    await tocar(tester, 'Cancelar tratamento');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar tratamento'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tratamentos.cancelamentos, 1);
    expect(find.text('Editar'), findsNothing);
    expect(find.textContaining('não pode mais ser alterado'), findsOneWidget);
  });

  testWidgets('concluído permite editar e reativar', (tester) async {
    await abrirDetalhe(
      tester,
      TratamentoFake([
        tratamentoExemplo(id: 5, status: StatusTratamento.concluido),
      ]),
      rota: Rotas.tratamento(5),
    );

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Reativar'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);
    expect(find.text('Cancelar tratamento'), findsNothing);
  });

  testWidgets('Editar abre o formulário preenchido', (tester) async {
    await abrirDetalhe(tester, TratamentoFake([tratamentoExemplo()]));

    await tocar(tester, 'Editar');

    expect(find.text('Editar tratamento'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Amoxicilina'), findsOneWidget);
  });

  testWidgets('erro ao carregar mostra a mensagem e permite tentar de novo', (
    tester,
  ) async {
    final tratamentos = TratamentoFake([tratamentoExemplo(id: 3)])
      ..erroBuscar = const ApiException('Tratamento não encontrado!', 404);
    await abrirDetalhe(tester, tratamentos, rota: Rotas.tratamento(3));

    expect(find.text('Tratamento não encontrado!'), findsOneWidget);

    await tocar(tester, 'Tentar de novo');
    expect(find.text('Amoxicilina'), findsOneWidget);
  });

  testWidgets('endereço com id inválido volta para a lista', (tester) async {
    await abrirDetalhe(
      tester,
      TratamentoFake(),
      rota: '/tratamentos/abc',
    );

    expect(find.text('Meus tratamentos:'), findsOneWidget);
  });
}
