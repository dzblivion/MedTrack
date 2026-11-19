import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/formatos.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/historico/historico_controller.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<void> abrirHistorico(WidgetTester tester, DoseFake doses) => abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        doses: doses,
        rota: Rotas.historico,
      );

  String hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Um horário no dia [diasAtras] dias antes de hoje, longe da meia-noite.
  DateTime noDia(int diasAtras, {int hora = 1}) {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day - diasAtras, hora);
  }

  String data(DateTime d) => '${diaDaSemana(d)}, ${formatarDiaMes(d)}';

  group('rótulo do dia', () {
    final controller = HistoricoController(
      DoseFake(),
      relogio: () => DateTime(2026, 11, 19, 15),
    );

    test('Hoje, Ontem e Anteontem vêm com o dia e a data', () {
      expect(
        controller.rotuloDoDia(DateTime(2026, 11, 19)),
        'Hoje – quinta, 19/11',
      );
      expect(
        controller.rotuloDoDia(DateTime(2026, 11, 18)),
        'Ontem – quarta, 18/11',
      );
      expect(
        controller.rotuloDoDia(DateTime(2026, 11, 17)),
        'Anteontem – terça, 17/11',
      );
      expect(controller.rotuloDoDia(DateTime(2026, 11, 16)), 'segunda, 16/11');
    });
  });

  test('o filtro de mês não passa do mês atual nem da primeira dose', () async {
    final doses = DoseFake([
      doseExemplo(id: 1, em: DateTime(2026, 9, 20, 8)),
      doseExemplo(id: 2, em: DateTime(2026, 11, 2, 8)),
    ]);
    final controller = HistoricoController(
      doses,
      relogio: () => DateTime(2026, 11, 19, 15),
    );
    addTearDown(controller.dispose);
    await controller.carregar();

    expect(controller.mes, DateTime(2026, 11));
    expect(controller.podeAvancar, isFalse);
    expect([for (final d in controller.dias) d.dia], [DateTime(2026, 11, 2)]);

    controller.mesAnterior();
    expect(controller.mes, DateTime(2026, 10));
    expect(controller.dias, isEmpty);

    controller.mesAnterior();
    expect(controller.mes, DateTime(2026, 9));
    expect(controller.podeVoltar, isFalse);
    controller.mesAnterior();
    expect(controller.mes, DateTime(2026, 9));

    controller.proximoMes();
    controller.proximoMes();
    expect(controller.mes, DateTime(2026, 11));
  });

  test('doses futuras ficam fora do histórico', () async {
    final controller = HistoricoController(
      DoseFake([
        doseExemplo(id: 1, em: DateTime(2026, 11, 19, 8)),
        doseExemplo(id: 2, em: DateTime(2026, 11, 19, 20)),
      ]),
      relogio: () => DateTime(2026, 11, 19, 15),
    );
    addTearDown(controller.dispose);
    await controller.carregar();

    expect([for (final d in controller.dias.single.doses) d.id], [1]);
  });

  testWidgets('agrupa por dia, com data em todos e o resumo de tomadas', (
    tester,
  ) async {
    final hoje = noDia(0);
    final ontem = noDia(1);
    final anteontem = noDia(2);
    final antes = noDia(3);

    await abrirHistorico(
      tester,
      DoseFake([
        doseExemplo(id: 1, medicamento: 'Losartana', em: hoje,
            status: StatusDose.tomada),
        doseExemplo(id: 2, em: ontem, status: StatusDose.tomada),
        doseExemplo(id: 3, em: ontem.add(const Duration(hours: 1)),
            status: StatusDose.naoTomada),
        doseExemplo(id: 4, em: anteontem, status: StatusDose.tomada),
        doseExemplo(id: 5, em: antes, status: StatusDose.tomada),
      ]),
    );

    expect(find.text('Seu histórico:'), findsOneWidget);
    expect(find.text(formatarMesAno(DateTime.now())), findsOneWidget);

    // Dias que caem no mês atual (os testes podem rodar no começo do mês).
    final mes = DateTime.now().month;
    if (hoje.month == mes) {
      expect(find.text('Hoje – ${data(hoje)}'), findsOneWidget);
      expect(find.text('Losartana'), findsOneWidget);
      expect(find.text('1 de 1 tomada'), findsWidgets);
    }
    if (ontem.month == mes) {
      expect(find.text('Ontem – ${data(ontem)}'), findsOneWidget);
      expect(find.text('1 de 2 tomadas'), findsOneWidget);
      expect(find.text('Não tomada'), findsOneWidget);
    }
    if (anteontem.month == mes) {
      await tester.scrollUntilVisible(
        find.text('Anteontem – ${data(anteontem)}'),
        200,
      );
      expect(find.text('Anteontem – ${data(anteontem)}'), findsOneWidget);
    }
    if (antes.month == mes) {
      await tester.scrollUntilVisible(find.text(data(antes)), 200);
      expect(find.text(data(antes)), findsOneWidget);
    }
  });

  testWidgets('dose esquecida de ontem pode ser registrada pelo histórico', (
    tester,
  ) async {
    // Mesmo dia do mês atual: hoje cedo, se ontem já for outro mês.
    final agora = DateTime.now();
    final esquecida = agora.day > 1 ? noDia(1, hora: 8) : noDia(0, hora: 0);
    final doses = DoseFake([doseExemplo(id: 9, em: esquecida)]);
    await abrirHistorico(tester, doses);

    expect(find.text(hhmm(esquecida)), findsOneWidget);
    expect(find.text('não registrada'), findsOneWidget);

    await tocar(tester, 'Tomei');

    expect(doses.registros, [(id: 9, tomada: true)]);
    expect(find.text('Dose registrada como tomada.'), findsOneWidget);
    expect(find.text('Tomada'), findsOneWidget);
    expect(find.text('não registrada'), findsNothing);
  });

  testWidgets('mês sem doses mostra o aviso', (tester) async {
    await abrirHistorico(tester, DoseFake());

    expect(
      find.text('Nenhuma dose em ${nomeDoMes(DateTime.now())}.'),
      findsOneWidget,
    );
    // Sem histórico, não há para onde ir.
    expect(
      tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
      ).onPressed,
      isNull,
    );
  });

  testWidgets('trocar de mês pelas setas', (tester) async {
    final agora = DateTime.now();
    final mesPassado = DateTime(agora.year, agora.month - 1, 10, 9);
    await abrirHistorico(
      tester,
      DoseFake([
        doseExemplo(id: 1, medicamento: 'Antiga', em: mesPassado,
            status: StatusDose.tomada),
      ]),
    );

    expect(find.text('Antiga'), findsNothing);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();

    expect(find.text(formatarMesAno(mesPassado)), findsOneWidget);
    expect(find.text('Antiga'), findsOneWidget);
    expect(find.text(data(mesPassado)), findsOneWidget);
  });

  testWidgets('erro ao carregar mostra a mensagem e permite tentar de novo', (
    tester,
  ) async {
    final doses = DoseFake([
      doseExemplo(em: noDia(0, hora: 0), status: StatusDose.tomada),
    ])..erro = const ApiException('Não foi possível conectar ao servidor.');
    await abrirHistorico(tester, doses);

    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);

    await tocar(tester, 'Tentar de novo');
    expect(find.text('Tomada'), findsOneWidget);
  });

  testWidgets('abrir a aba Histórico recarrega', (tester) async {
    final doses = DoseFake();
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      doses: doses,
      rota: Rotas.inicio,
    );

    await tocar(tester, 'Histórico');
    final antes = doses.buscas;

    await tocar(tester, 'Início');
    doses.doses = [
      doseExemplo(medicamento: 'Nova', em: noDia(0, hora: 0),
          status: StatusDose.tomada),
    ];
    await tocar(tester, 'Histórico');

    expect(doses.buscas, greaterThan(antes));
    expect(find.text('Nova'), findsOneWidget);
  });
}
