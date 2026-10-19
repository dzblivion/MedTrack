import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/formatos.dart';
import 'package:frontend/features/tratamentos/tratamentos_screen.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);

  // Campos de texto do formulário, na ordem em que aparecem na tela.
  const medicamento = 0, dosagem = 1, quantidade = 2, duracao = 4;

  Future<void> abrirFormulario(
    WidgetTester tester,
    TratamentoFake tratamentos,
  ) async {
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      tratamentos: tratamentos,
      rota: Rotas.tratamentos,
    );
    await tocar(tester, 'Novo tratamento');
  }

  Future<void> preencher(WidgetTester tester, int campo, String texto) =>
      tester.enterText(find.byType(TextFormField).at(campo), texto);

  testWidgets('abre por cima do menu, com unidade, forma, quantidade e data '
      'já preenchidas', (tester) async {
    await abrirFormulario(tester, TratamentoFake());

    expect(find.text('Salvar tratamento'), findsOneWidget);
    expect(find.text('Início'), findsNothing);
    expect(find.text('mg'), findsOneWidget);
    expect(find.text('Oral'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, formatarData(hoje)), findsOneWidget);
  });

  testWidgets('o calendário abre em português e muda a data de início', (
    tester,
  ) async {
    await abrirFormulario(tester, TratamentoFake());

    await tester.tap(find.widgetWithText(TextFormField, formatarData(hoje)));
    await tester.pumpAndSettle();

    expect(find.text('Data de início'), findsWidgets);
    expect(find.text('Cancelar'), findsOneWidget);

    // Escolhe o dia 1 do mês aberto (ou o 2, se hoje for dia 1).
    final dia = hoje.day == 1 ? 2 : 1;
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('$dia')),
    );
    await tocar(tester, 'OK');

    final esperado = DateTime(hoje.year, hoje.month, dia);
    expect(
      find.widgetWithText(TextFormField, formatarData(esperado)),
      findsOneWidget,
    );
  });

  testWidgets('valida os campos antes de enviar', (tester) async {
    final tratamentos = TratamentoFake();
    await abrirFormulario(tester, tratamentos);

    await preencher(tester, quantidade, '0');
    await preencher(tester, duracao, '4000');
    await tocar(tester, 'Salvar tratamento');

    expect(find.text('Informe o medicamento'), findsOneWidget);
    expect(find.text('Informe a dosagem'), findsOneWidget);
    expect(find.text('Deve ser maior que zero'), findsOneWidget);
    expect(find.text('Entre 1 e 3650 dias'), findsOneWidget);
    expect(tratamentos.criado, isNull);
  });

  testWidgets('cadastra no formato da API e volta para a lista atualizada', (
    tester,
  ) async {
    final tratamentos = TratamentoFake();
    await abrirFormulario(tester, tratamentos);

    await preencher(tester, medicamento, '  Dipirona  ');
    await preencher(tester, dosagem, '0,5');
    await preencher(tester, quantidade, '2');
    await preencher(tester, duracao, '5');
    await tocar(tester, 'Salvar tratamento');

    expect(tratamentos.criado, {
      'medicamento': 'Dipirona',
      'dosagem_valor': 0.5,
      'dosagem_unidade': 'mg',
      'quantidade_por_dose': 2.0,
      'forma_consumo': 'oral',
      'data_inicio': formatarDataApi(hoje),
      'duracao_dias': 5,
    });
    expect(find.text('Meus tratamentos:'), findsOneWidget);
    expect(find.text('Tratamento cadastrado!'), findsOneWidget);
    expect(tratamentos.buscas, 2);
  });

  testWidgets('erro da API aparece e o formulário continua aberto', (
    tester,
  ) async {
    final tratamentos = TratamentoFake()
      ..erroSalvar = const ApiException('Medicamento é obrigatório!', 400);
    await abrirFormulario(tester, tratamentos);

    await preencher(tester, medicamento, 'Dipirona');
    await preencher(tester, dosagem, '500');
    await preencher(tester, duracao, '5');
    await tocar(tester, 'Salvar tratamento');

    expect(find.text('Medicamento é obrigatório!'), findsOneWidget);
    expect(find.text('Salvar tratamento'), findsOneWidget);
  });

  testWidgets('editar abre preenchido e envia para o tratamento certo', (
    tester,
  ) async {
    final original = tratamentoExemplo(id: 7, medicamento: 'Amoxicilina');
    final tratamentos = TratamentoFake([original]);
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      tratamentos: tratamentos,
      rota: Rotas.tratamentos,
    );

    GoRouter.of(tester.element(find.byType(TratamentosScreen)))
        .push(Rotas.editarTratamento(7), extra: original);
    await tester.pumpAndSettle();

    expect(find.text('Editar tratamento'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Amoxicilina'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '500'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '7'), findsOneWidget);

    await preencher(tester, medicamento, 'Amoxicilina 875');
    await tocar(tester, 'Salvar alterações');

    expect(tratamentos.atualizado?.id, 7);
    expect(tratamentos.atualizado?.dados['medicamento'], 'Amoxicilina 875');
    expect(find.text('Tratamento atualizado!'), findsOneWidget);
  });

  testWidgets('abrir a edição sem o tratamento volta para a lista', (
    tester,
  ) async {
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      tratamentos: TratamentoFake(),
      rota: Rotas.editarTratamento(7),
    );

    expect(find.text('Meus tratamentos:'), findsOneWidget);
  });
}
