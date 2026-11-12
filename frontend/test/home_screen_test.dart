import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/home/widgets/card_doses_do_dia.dart';
import 'package:frontend/features/home/widgets/card_proxima_dose.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<void> abrirHome(WidgetTester tester, DoseFake doses) => abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        doses: doses,
        rota: Rotas.inicio,
      );

  String hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Procura [texto] só dentro do card da próxima dose ou só na lista.
  Finder noCard(String texto) => find.descendant(
        of: find.byType(CardProximaDose),
        matching: find.text(texto),
      );
  Finder naLista(String texto) => find.descendant(
        of: find.byType(CardDosesDoDia),
        matching: find.text(texto),
      );

  bool habilitado(WidgetTester tester, String texto) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, texto))
      .enabled;

  testWidgets('a próxima dose é a atrasada mais antiga; adesão do dia', (
    tester,
  ) async {
    final agora = DateTime.now();
    final atrasada = agora.subtract(const Duration(hours: 1));
    await abrirHome(
      tester,
      DoseFake([
        doseExemplo(
          id: 1,
          em: agora.subtract(const Duration(hours: 3)),
          status: StatusDose.tomada,
        ),
        doseExemplo(id: 2, medicamento: 'Losartana', em: atrasada),
        doseExemplo(id: 3, em: agora.add(const Duration(hours: 2))),
      ]),
    );

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Olá,'), findsOneWidget);
    expect(find.text('Seu tratamento de hoje:'), findsOneWidget);

    expect(noCard(hhmm(atrasada)), findsOneWidget);
    expect(noCard('Losartana'), findsOneWidget);
    expect(noCard('atrasada'), findsOneWidget);
    expect(habilitado(tester, 'Já tomei'), isTrue);
    expect(habilitado(tester, 'Não tomei'), isTrue);

    expect(find.text('1 de 3 doses'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
  });

  testWidgets('a lista mostra todas as doses do dia, cada uma com a situação', (
    tester,
  ) async {
    final agora = DateTime.now();
    await abrirHome(
      tester,
      DoseFake([
        doseExemplo(
          id: 1,
          medicamento: 'Losartana',
          em: agora.subtract(const Duration(hours: 4)),
          status: StatusDose.tomada,
        ),
        doseExemplo(
          id: 2,
          medicamento: 'Retalina',
          em: agora.subtract(const Duration(hours: 3)),
          status: StatusDose.naoTomada,
        ),
        doseExemplo(
          id: 3,
          medicamento: 'Paracetamol',
          em: agora.subtract(const Duration(hours: 1)),
        ),
        doseExemplo(
          id: 4,
          medicamento: 'Vitamina D',
          em: agora.add(const Duration(hours: 2)),
        ),
      ]),
    );

    expect(find.text('Doses de hoje'), findsOneWidget);
    for (final nome in ['Losartana', 'Retalina', 'Paracetamol', 'Vitamina D']) {
      expect(naLista(nome), findsOneWidget);
    }
    expect(naLista('Tomada'), findsOneWidget);
    expect(naLista('Não tomada'), findsOneWidget);
    expect(naLista('Tomei'), findsOneWidget);
    expect(naLista('atrasada'), findsOneWidget);
    expect(naLista('aguardando'), findsOneWidget);

    // Em ordem de horário.
    final posicoes = [
      for (final nome in ['Losartana', 'Retalina', 'Paracetamol', 'Vitamina D'])
        tester.getTopLeft(naLista(nome)).dy,
    ];
    expect(posicoes, [...posicoes]..sort());
  });

  testWidgets('dá para registrar qualquer dose que já chegou pela lista', (
    tester,
  ) async {
    final agora = DateTime.now();
    final doses = DoseFake([
      doseExemplo(
        id: 1,
        medicamento: 'Losartana',
        em: agora.subtract(const Duration(hours: 2)),
      ),
      doseExemplo(
        id: 2,
        medicamento: 'Retalina',
        em: agora.subtract(const Duration(hours: 1)),
      ),
    ]);
    await abrirHome(tester, doses);

    // A segunda da lista (Retalina), que não é a do card.
    // Centraliza a linha, para o toque não cair atrás do menu inferior.
    await Scrollable.ensureVisible(
      tester.element(naLista('Não').last),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(naLista('Não').last);
    await tester.pumpAndSettle();

    expect(doses.registros, [(id: 2, tomada: false)]);
    expect(naLista('Não tomada'), findsOneWidget);
    // A Losartana continua pendente, com os botões.
    expect(naLista('Tomei'), findsOneWidget);
  });

  testWidgets('só fica atrasada (vermelha) 1 minuto depois do horário', (
    tester,
  ) async {
    final agora = DateTime.now();
    await abrirHome(
      tester,
      DoseFake([
        doseExemplo(
          id: 1,
          medicamento: 'Na hora',
          em: agora.subtract(const Duration(seconds: 20)),
        ),
      ]),
    );

    expect(find.text('atrasada'), findsNothing);
    expect(habilitado(tester, 'Já tomei'), isTrue);
  });

  testWidgets('antes do horário, os botões ficam bloqueados', (tester) async {
    final depois = DateTime.now().add(const Duration(hours: 2));
    await abrirHome(tester, DoseFake([doseExemplo(em: depois)]));

    expect(noCard(hhmm(depois)), findsOneWidget);
    expect(
      find.text('Você poderá registrar a partir das ${hhmm(depois)}.'),
      findsOneWidget,
    );
    expect(habilitado(tester, 'Já tomei'), isFalse);
    expect(habilitado(tester, 'Não tomei'), isFalse);
    expect(naLista('aguardando'), findsOneWidget);
  });

  testWidgets('Já tomei registra, recarrega e atualiza a adesão', (
    tester,
  ) async {
    final doses = DoseFake([
      doseExemplo(id: 7, em: DateTime.now().subtract(const Duration(minutes: 5))),
    ]);
    await abrirHome(tester, doses);
    expect(find.text('0 de 1 doses'), findsOneWidget);

    await tocar(tester, 'Já tomei');

    expect(doses.registros, [(id: 7, tomada: true)]);
    expect(doses.buscas, 2);
    expect(find.text('Dose registrada como tomada.'), findsOneWidget);
    expect(find.text('1 de 1 doses'), findsOneWidget);
    expect(find.text('Todas as doses de hoje foram registradas.'), findsOneWidget);
    expect(naLista('Tomada'), findsOneWidget);
  });

  testWidgets('Não tomei registra como não tomada', (tester) async {
    final doses = DoseFake([
      doseExemplo(id: 4, em: DateTime.now().subtract(const Duration(minutes: 5))),
    ]);
    await abrirHome(tester, doses);

    await tocar(tester, 'Não tomei');

    expect(doses.registros, [(id: 4, tomada: false)]);
    expect(find.text('0 de 1 doses'), findsOneWidget);
  });

  testWidgets('erro ao registrar mostra a mensagem da API', (tester) async {
    final doses = DoseFake([
      doseExemplo(em: DateTime.now().subtract(const Duration(minutes: 5))),
    ])..erroRegistrar = const ApiException(
        'Esta dose já foi registrada e não pode ser alterada novamente!',
        400,
      );
    await abrirHome(tester, doses);

    await tocar(tester, 'Já tomei');

    expect(
      find.text('Esta dose já foi registrada e não pode ser alterada novamente!'),
      findsOneWidget,
    );
  });

  testWidgets('sem doses hoje, sem lista', (tester) async {
    await abrirHome(tester, DoseFake());

    expect(find.text('Nenhuma dose agendada para hoje.'), findsOneWidget);
    expect(find.text('sem doses hoje'), findsOneWidget);
    expect(find.text('Doses de hoje'), findsNothing);
    expect(find.text('Já tomei'), findsNothing);
  });

  testWidgets('erro ao carregar mostra a mensagem e permite tentar de novo', (
    tester,
  ) async {
    final doses = DoseFake([
      doseExemplo(em: DateTime.now().add(const Duration(hours: 1))),
    ])..erro = const ApiException('Não foi possível conectar ao servidor.');
    await abrirHome(tester, doses);

    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);

    await tocar(tester, 'Tentar de novo');

    expect(find.text('Próxima dose'), findsOneWidget);
    expect(doses.buscas, 2);
  });

  testWidgets('abrir a aba Início recarrega (ex.: tratamento novo)', (
    tester,
  ) async {
    final doses = DoseFake();
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      doses: doses,
      rota: Rotas.tratamentos,
    );

    // Um tratamento cadastrado na aba Tratamentos gera doses novas.
    final nova = DateTime.now().add(const Duration(hours: 1));
    doses.doses = [doseExemplo(medicamento: 'Retalina', em: nova)];
    await tocar(tester, 'Início');

    expect(noCard('Retalina'), findsOneWidget);
    expect(noCard(hhmm(nova)), findsOneWidget);
  });

  testWidgets('puxar para baixo atualiza as doses', (tester) async {
    final doses = DoseFake();
    await abrirHome(tester, doses);
    expect(find.text('Nenhuma dose agendada para hoje.'), findsOneWidget);

    doses.doses = [
      doseExemplo(em: DateTime.now().add(const Duration(hours: 1))),
    ];
    await tester.fling(find.text('Próxima dose'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(noCard('Amoxicilina'), findsOneWidget);
  });

  testWidgets('Nova prescrição e a MIA avisam que chegam em breve', (
    tester,
  ) async {
    await abrirHome(tester, DoseFake());

    await tocar(tester, 'Conhecer a MIA');
    expect(
      find.text('A leitura de prescrição pela MIA chega em breve.'),
      findsOneWidget,
    );
  });
}
