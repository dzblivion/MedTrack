import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/formatos.dart';
import 'package:frontend/features/tratamentos/frequencia.dart';
import 'package:frontend/features/tratamentos/tratamentos_screen.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final ancoraHoje = formatarDataApi(hoje);

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

  /// Campos de texto da etapa aberta, na ordem em que aparecem.
  Future<void> preencher(WidgetTester tester, int campo, String texto) =>
      tester.enterText(find.byType(TextFormField).at(campo), texto);

  /// Abre a lista de opções que mostra [atual] e escolhe [opcao].
  Future<void> escolher(WidgetTester tester, String atual, String opcao) async {
    final lista = find.ancestor(
      of: find.text(atual),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(lista);
    await tester.tap(lista);
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcao).last);
    await tester.pumpAndSettle();
  }

  /// Adiciona um horário aceitando o que o relógio sugere.
  Future<void> adicionarHorario(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Adicionar horário'));
    await tester.pumpAndSettle();
    await tocar(tester, 'OK');
  }

  // Etapa 1: medicamento -> nome, dosagem, quantidade.
  Future<void> etapaMedicamento(
    WidgetTester tester, {
    String nome = 'Dipirona',
    String? dosagem,
  }) async {
    await preencher(tester, 0, nome);
    if (dosagem != null) {
      await preencher(tester, 1, dosagem);
      await escolher(tester, 'Unidade', 'mg');
    }
    await preencher(tester, 2, '2');
    await escolher(tester, 'Selecione uma opção', 'Oral');
    await tocar(tester, 'Continuar');
  }

  Future<void> etapaFrequenciaDiaria(WidgetTester tester) async {
    await escolher(tester, 'Selecione a frequência', 'Todos os dias');
    await adicionarHorario(tester);
    await tocar(tester, 'Continuar');
  }

  testWidgets('abre na etapa 1, por cima do menu', (tester) async {
    await abrirFormulario(tester, TratamentoFake());

    expect(find.text('Etapa 1 de 3'), findsOneWidget);
    expect(find.text('Novo tratamento'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Selecione uma opção'), findsOneWidget);
    expect(find.text('Início'), findsNothing);
  });

  testWidgets('etapa 1 valida antes de avançar', (tester) async {
    await abrirFormulario(tester, TratamentoFake());

    await preencher(tester, 1, '500');
    await preencher(tester, 2, '0');
    await tocar(tester, 'Continuar');

    expect(find.text('Informe o medicamento'), findsOneWidget);
    expect(find.text('Escolha a forma de consumo'), findsOneWidget);
    expect(find.text('Escolha a unidade'), findsOneWidget);
    expect(find.text('Deve ser maior que zero'), findsOneWidget);
    expect(find.text('Etapa 1 de 3'), findsOneWidget);
  });

  testWidgets('etapa 2 pede a frequência e pelo menos um horário', (
    tester,
  ) async {
    await abrirFormulario(tester, TratamentoFake());
    await etapaMedicamento(tester);

    expect(find.text('Frequência e horários'), findsOneWidget);
    await tocar(tester, 'Continuar');
    expect(find.text('Escolha a frequência'), findsOneWidget);
    expect(find.text('Adicione pelo menos um horário'), findsOneWidget);

    await escolher(tester, 'Selecione a frequência', 'Dias da semana');
    await tocar(tester, 'Continuar');
    expect(find.text('Escolha pelo menos um dia'), findsOneWidget);
    expect(find.text('Etapa 2 de 3'), findsOneWidget);
  });

  testWidgets('horários: adiciona, não repete e remove', (tester) async {
    await abrirFormulario(tester, TratamentoFake());
    await etapaMedicamento(tester);
    await escolher(tester, 'Selecione a frequência', 'Todos os dias');

    await adicionarHorario(tester);
    await adicionarHorario(tester);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover 08:00'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsNothing);
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('o calendário abre em português e muda a data de início', (
    tester,
  ) async {
    await abrirFormulario(tester, TratamentoFake());
    await etapaMedicamento(tester);

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

  testWidgets('voltar leva à etapa anterior sem perder o que foi preenchido', (
    tester,
  ) async {
    await abrirFormulario(tester, TratamentoFake());
    await etapaMedicamento(tester);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Etapa 1 de 3'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Dipirona'), findsOneWidget);
    expect(find.text('Oral'), findsOneWidget);
  });

  testWidgets('etapa 3 valida a duração e calcula a data de término', (
    tester,
  ) async {
    await abrirFormulario(tester, TratamentoFake());
    await etapaMedicamento(tester);
    await etapaFrequenciaDiaria(tester);

    expect(find.text('Duração e revisão'), findsOneWidget);
    await tocar(tester, 'Salvar tratamento');
    expect(find.text('Informe a duração'), findsOneWidget);

    await preencher(tester, 0, '4000');
    await tocar(tester, 'Salvar tratamento');
    expect(find.text('Entre 1 e 3650 dias'), findsOneWidget);

    await preencher(tester, 0, '5');
    await tester.pumpAndSettle();
    final fim = DateTime(hoje.year, hoje.month, hoje.day + 4);
    expect(find.widgetWithText(TextFormField, formatarData(fim)), findsOneWidget);
  });

  testWidgets('cadastra diário com término no formato da API', (tester) async {
    final tratamentos = TratamentoFake();
    await abrirFormulario(tester, tratamentos);

    await etapaMedicamento(tester, nome: '  Dipirona  ', dosagem: '0,5');
    await etapaFrequenciaDiaria(tester);
    await preencher(tester, 0, '5');
    await tester.pumpAndSettle();

    expect(find.text('Diário · 08:00'), findsOneWidget);
    expect(find.text('0,5 mg · 2 por dose'), findsOneWidget);

    await tocar(tester, 'Salvar tratamento');

    expect(tratamentos.criado, {
      'medicamento': 'Dipirona',
      'dosagem_valor': 0.5,
      'dosagem_unidade': 'mg',
      'quantidade_por_dose': 2.0,
      'forma_consumo': 'oral',
      'data_inicio': ancoraHoje,
      'duracao_dias': 5,
      'frequencia': {
        'tipo': 'diario',
        'ancora_em': '${ancoraHoje}T00:00:00-03:00',
        'horarios': ['08:00'],
        'dias_semana': <int>[],
        'intervalo_valor': null,
      },
    });
    expect(find.text('Meus tratamentos:'), findsOneWidget);
    expect(find.text('Tratamento cadastrado!'), findsOneWidget);
    expect(tratamentos.buscas, 2);
  });

  testWidgets('a cada 8 horas e contínuo: ancora na primeira dose', (
    tester,
  ) async {
    final tratamentos = TratamentoFake();
    await abrirFormulario(tester, tratamentos);
    await etapaMedicamento(tester);

    await escolher(tester, 'Selecione a frequência', 'Em intervalos');
    await preencher(tester, 0, '8');
    await adicionarHorario(tester);
    // Em intervalos só existe o horário da primeira dose.
    expect(find.byTooltip('Adicionar horário'), findsNothing);
    await tocar(tester, 'Continuar');

    await tocar(tester, 'Contínuo');
    expect(find.text('Duração (dias)*'), findsNothing);
    expect(find.text('A cada 8 horas · início às 08:00'), findsOneWidget);
    await tocar(tester, 'Salvar tratamento');

    expect(tratamentos.criado?['dosagem_valor'], isNull);
    expect(tratamentos.criado?['dosagem_unidade'], isNull);
    expect(tratamentos.criado?['duracao_dias'], isNull);
    expect(tratamentos.criado?['frequencia'], {
      'tipo': 'intervalo_horas',
      'ancora_em': '${ancoraHoje}T08:00:00-03:00',
      'horarios': <String>[],
      'dias_semana': <int>[],
      'intervalo_valor': 8,
    });
  });

  testWidgets('semanal envia os dias marcados (segunda = 1)', (tester) async {
    final tratamentos = TratamentoFake();
    await abrirFormulario(tester, tratamentos);
    await etapaMedicamento(tester);

    await escolher(tester, 'Selecione a frequência', 'Dias da semana');
    await tocar(tester, 'Qua');
    await tocar(tester, 'Seg');
    await adicionarHorario(tester);
    await tocar(tester, 'Continuar');

    expect(find.text('Seg, Qua · 08:00'), findsOneWidget);
    await preencher(tester, 0, '14');
    await tocar(tester, 'Salvar tratamento');

    final frequencia = tratamentos.criado?['frequencia'] as Map;
    expect(frequencia['tipo'], 'semanal');
    expect(frequencia['dias_semana'], [1, 3]);
    expect(frequencia['horarios'], ['08:00']);
  });

  testWidgets('erro da API aparece e o formulário continua aberto', (
    tester,
  ) async {
    final tratamentos = TratamentoFake()
      ..erroSalvar = const ApiException('Medicamento é obrigatório!', 400);
    await abrirFormulario(tester, tratamentos);
    await etapaMedicamento(tester);
    await etapaFrequenciaDiaria(tester);
    await preencher(tester, 0, '5');
    await tocar(tester, 'Salvar tratamento');

    expect(find.text('Medicamento é obrigatório!'), findsOneWidget);
    expect(find.text('Salvar tratamento'), findsOneWidget);
  });

  testWidgets('editar abre preenchido nas 3 etapas e envia para o certo', (
    tester,
  ) async {
    final original = tratamentoExemplo(
      id: 7,
      medicamento: 'Amoxicilina',
      frequencia: const Frequencia(
        tipo: TipoFrequencia.diario,
        horarios: ['08:00', '20:00'],
      ),
    );
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

    await preencher(tester, 0, 'Amoxicilina 875');
    await tocar(tester, 'Continuar');
    expect(find.text('Todos os dias'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);

    await tocar(tester, 'Continuar');
    expect(find.widgetWithText(TextFormField, '7'), findsOneWidget);
    await tocar(tester, 'Salvar alterações');

    expect(tratamentos.atualizado?.id, 7);
    expect(tratamentos.atualizado?.dados['medicamento'], 'Amoxicilina 875');
    expect(
      (tratamentos.atualizado?.dados['frequencia'] as Map)['horarios'],
      ['08:00', '20:00'],
    );
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
