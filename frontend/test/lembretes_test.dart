import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/mudancas.dart';
import 'package:frontend/features/auth/sessao_controller.dart';
import 'package:frontend/features/auth/usuario.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/lembretes/botoes_dose.dart';
import 'package:frontend/features/lembretes/lembretes_controller.dart';
import 'package:frontend/features/lembretes/preferencias_lembretes.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  group('agenda dos lembretes', () {
    final agora = DateTime(2026, 11, 27, 10);

    Future<SessaoController> sessaoDe(Usuario usuario) async {
      final sessao = SessaoController(
        AuthFake(),
        storageComSessao(DateTime(2100), usuario: usuario),
        ApiClient(),
      );
      await sessao.restaurar();
      return sessao;
    }

    Future<LembretesController> iniciar({
      required List<Dose> doses,
      PreferenciasLembretes preferencias = const PreferenciasLembretes(),
      NotificadorFake? notificador,
      Usuario usuario = maria,
      Mudancas? mudancas,
      DoseFake? repositorio,
    }) async {
      final controller = LembretesController(
        notificador ?? NotificadorFake(),
        ArmazenamentoLembretesFake(preferencias),
        repositorio ?? DoseFake(doses),
        await sessaoDe(usuario),
        mudancas: mudancas,
        relogio: () => agora,
      );
      await controller.iniciar();
      return controller;
    }

    Dose dose(
      int id,
      int hora, {
      StatusDose status = StatusDose.pendente,
      String medicamento = 'Losartana',
    }) => doseExemplo(
      id: id,
      medicamento: medicamento,
      em: DateTime(2026, 11, 27, hora),
      status: status,
    );

    test('agenda o aviso na hora, com os botões da dose', () async {
      final notificador = NotificadorFake();
      final controller = await iniciar(
        notificador: notificador,
        doses: [dose(3, 14)],
      );

      expect(notificador.agendados.keys, [6]);
      final aviso = notificador.agendados[6]!;
      expect(aviso.quando, DateTime(2026, 11, 27, 14));
      expect(aviso.titulo, 'Hora de tomar Losartana');
      expect(aviso.texto, '500 mg · 1 por dose · 14:00');
      // Os dados fazem o aviso ter os botões Tomei / Não tomei.
      expect(jsonDecode(aviso.dados!), {
        'dose': 3,
        'remedio': 'Losartana',
        'horario': '14:00',
      });
      expect(controller.agendados, 1);
    });

    test('ignora doses já registradas ou com horário passado', () async {
      final notificador = NotificadorFake();
      await iniciar(
        notificador: notificador,
        doses: [
          dose(1, 8),
          dose(2, 12, status: StatusDose.tomada),
          dose(3, 14),
        ],
      );

      expect(notificador.agendados.keys, [6]);
    });

    test('o aviso antes só lembra; o da hora continua com os botões', () async {
      final notificador = NotificadorFake();
      await iniciar(
        notificador: notificador,
        preferencias: const PreferenciasLembretes(minutosAntes: 15),
        doses: [dose(3, 14)],
      );

      expect(notificador.agendados.keys, unorderedEquals([6, 7]));
      final antes = notificador.agendados[7]!;
      expect(antes.quando, DateTime(2026, 11, 27, 13, 45));
      expect(antes.titulo, 'Daqui a 15 min: Losartana');
      expect(antes.dados, isNull);
      expect(notificador.agendados[6]!.quando, DateTime(2026, 11, 27, 14));
      expect(notificador.agendados[6]!.dados, isNotNull);
    });

    test('sem aviso antes se o horário dele já passou', () async {
      final notificador = NotificadorFake();
      await iniciar(
        notificador: notificador,
        preferencias: const PreferenciasLembretes(minutosAntes: 30),
        doses: [doseExemplo(id: 3, em: DateTime(2026, 11, 27, 10, 10))],
      );

      expect(notificador.agendados.keys, [6]);
    });

    test('desligado não agenda nada', () async {
      final notificador = NotificadorFake();
      await iniciar(
        notificador: notificador,
        preferencias: const PreferenciasLembretes(ativo: false),
        doses: [dose(3, 14)],
      );

      expect(notificador.agendados, isEmpty);
    });

    test('desligar apaga os já agendados e salva a escolha', () async {
      final notificador = NotificadorFake();
      final controller = await iniciar(
        notificador: notificador,
        doses: [dose(3, 14)],
      );
      expect(notificador.agendados, isNotEmpty);

      await controller.alterar(const PreferenciasLembretes(ativo: false));

      expect(notificador.agendados, isEmpty);
      expect(controller.preferencias.ativo, isFalse);
    });

    test('profissional não tem lembretes', () async {
      final notificador = NotificadorFake();
      await iniciar(
        notificador: notificador,
        usuario: draAna,
        doses: [dose(3, 14)],
      );

      expect(notificador.agendados, isEmpty);
    });

    test('sair da conta apaga os lembretes', () async {
      final notificador = NotificadorFake();
      final sessao = await sessaoDe(maria);
      final controller = LembretesController(
        notificador,
        ArmazenamentoLembretesFake(),
        DoseFake([dose(3, 14)]),
        sessao,
        relogio: () => agora,
      );
      await controller.iniciar();
      expect(notificador.agendados, isNotEmpty);

      await sessao.sair();
      await pumpEventQueue();

      expect(notificador.agendados, isEmpty);
      expect(controller.agendados, 0);
    });

    test('marcar a dose no app tira o aviso dela', () async {
      final notificador = NotificadorFake();
      final controller = await iniciar(
        notificador: notificador,
        doses: [dose(3, 14), dose(4, 20)],
      );

      await controller.doseRegistrada(dose(3, 14));

      expect(notificador.agendados.keys, [8]);
    });

    test('refaz a agenda quando um tratamento muda', () async {
      final notificador = NotificadorFake();
      final mudancas = Mudancas();
      final repositorio = DoseFake([dose(3, 14)]);
      await iniciar(
        notificador: notificador,
        mudancas: mudancas,
        repositorio: repositorio,
        doses: const [],
      );

      repositorio.doses = [dose(3, 14), dose(5, 18, medicamento: 'Insulina')];
      mudancas.tratamentosMudaram();
      await pumpEventQueue();

      expect(notificador.agendados[10]!.titulo, 'Hora de tomar Insulina');
    });

    test('agenda só as 50 doses mais próximas', () async {
      final notificador = NotificadorFake();
      final controller = await iniciar(
        notificador: notificador,
        doses: [
          for (var i = 1; i <= 80; i++)
            doseExemplo(
              id: i,
              em: agora.add(Duration(hours: i)),
            ),
        ],
      );

      expect(notificador.agendados, hasLength(50));
      expect(controller.agendados, 50);
      expect(notificador.agendados.containsKey(2 * 50), isTrue);
      expect(notificador.agendados.containsKey(2 * 51), isFalse);
    });

    test('ao voltar ao app, refaz se o relógio voltou no tempo', () async {
      var relogio = agora;
      final notificador = NotificadorFake();
      final repositorio = DoseFake([dose(3, 14)]);
      final controller = LembretesController(
        notificador,
        ArmazenamentoLembretesFake(),
        repositorio,
        await sessaoDe(maria),
        relogio: () => relogio,
      );
      await controller.iniciar();

      // Logo depois: não refaz (no máximo a cada 5 minutos).
      repositorio.doses = [dose(3, 14), dose(5, 18)];
      relogio = agora.add(const Duration(minutes: 1));
      await controller.appVoltou();
      expect(notificador.agendados.containsKey(10), isFalse);

      // Relógio voltou 3 horas (ex.: trocou o fuso): refaz na hora.
      relogio = agora.subtract(const Duration(hours: 3));
      await controller.appVoltou();
      expect(notificador.agendados.containsKey(10), isTrue);
    });

    test('no navegador não agenda nada', () async {
      final notificador = NotificadorFake(agendaNoAparelho: false);
      await iniciar(notificador: notificador, doses: [dose(3, 14)]);

      expect(notificador.agendados, isEmpty);
    });

    test('pede permissão ao entrar quando estão bloqueadas', () async {
      final notificador = NotificadorFake()..estadoPermissao = false;
      final controller = await iniciar(
        notificador: notificador,
        doses: [dose(3, 14)],
      );

      expect(notificador.pedidos, 1);
      expect(controller.permitido, isTrue);
    });
  });

  group('tela de notificações', () {
    Future<void> abrir(
      WidgetTester tester, {
      NotificadorFake? notificador,
      ArmazenamentoLembretesFake? armazenamento,
    }) async {
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        notificador: notificador,
        armazenamentoLembretes: armazenamento,
        rota: Rotas.perfil,
      );
      await tocar(tester, 'Notificações');
    }

    testWidgets('abre pelo Perfil com os lembretes ligados', (tester) async {
      await abrir(tester);

      expect(find.text('Lembrete das doses'), findsOneWidget);
      expect(find.text('Lembrar antes também'), findsOneWidget);
      expect(find.text('Não'), findsOneWidget);
      expect(
        find.text('Nenhuma dose pendente para lembrar agora.'),
        findsOneWidget,
      );
    });

    testWidgets('salva quando avisar e o desligar', (tester) async {
      final armazenamento = ArmazenamentoLembretesFake();
      await abrir(tester, armazenamento: armazenamento);

      await tocar(tester, '15 min antes');
      expect(armazenamento.salvas.minutosAntes, 15);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(armazenamento.salvas.ativo, isFalse);
    });

    testWidgets('envia a notificação de teste', (tester) async {
      final notificador = NotificadorFake();
      await abrir(tester, notificador: notificador);

      await tocar(tester, 'Enviar notificação de teste');

      expect(notificador.mostradas, hasLength(1));
      expect(find.text('Notificação de teste enviada.'), findsOneWidget);
    });

    testWidgets('avisa quando as notificações estão bloqueadas', (
      tester,
    ) async {
      final notificador = NotificadorFake(permite: false);
      await abrir(tester, notificador: notificador);

      await tocar(tester, 'Enviar notificação de teste');

      expect(notificador.mostradas, isEmpty);
      expect(find.textContaining('estão bloqueadas'), findsWidgets);
    });

    testWidgets('no navegador explica que os lembretes são no celular', (
      tester,
    ) async {
      await abrir(
        tester,
        notificador: NotificadorFake(agendaNoAparelho: false),
      );

      expect(
        find.textContaining('lembretes funcionam no app instalado'),
        findsOneWidget,
      );
    });

    testWidgets('o Perfil do profissional não tem Notificações', (
      tester,
    ) async {
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora, usuario: draAna),
        rota: Rotas.perfil,
      );

      expect(find.text('Notificações'), findsNothing);
    });
  });

  testWidgets('marcar a dose no Início tira o aviso dela', (
    tester,
  ) async {
    final agora = DateTime.now();
    final notificador = NotificadorFake();
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      notificador: notificador,
      doses: DoseFake([
        doseExemplo(id: 3, em: agora.subtract(const Duration(minutes: 5))),
      ]),
      rota: Rotas.inicio,
    );
    // Simula o aviso desta dose ainda na tela.
    await notificador.agendar(
      id: 6,
      quando: agora.subtract(const Duration(minutes: 5)),
      titulo: 'Hora de tomar Amoxicilina',
      texto: '',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Tomei').first);
    await tester.pumpAndSettle();

    expect(notificador.agendados.containsKey(6), isFalse);
  });

  group('botões Tomei / Não tomei da notificação', () {
    final dados = dadosDoAviso(
      doseId: 3,
      medicamento: 'Losartana',
      horario: '14:00',
    );

    Future<
      ({List<(String, int, bool)> registros, List<String> falhas, List<int> avisados})
    >
    tocarBotao({
      required String? acao,
      String? token = 'token-salvo',
      Object? erro,
    }) async {
      final registros = <(String, int, bool)>[];
      final falhas = <String>[];
      final avisados = <int>[];
      await tratarBotaoDaDose(
        acao: acao,
        dados: dados,
        lerToken: () async => token,
        registrar: (token, doseId, tomada) async {
          if (erro != null) throw erro;
          registros.add((token, doseId, tomada));
        },
        avisarFalha: (titulo, texto) async => falhas.add('$titulo|$texto'),
        aoRegistrar: avisados.add,
      );
      return (registros: registros, falhas: falhas, avisados: avisados);
    }

    test('Tomei registra a dose como tomada com o login salvo', () async {
      final r = await tocarBotao(acao: acaoTomei);

      expect(r.registros, [('token-salvo', 3, true)]);
      expect(r.avisados, [3]);
      expect(r.falhas, isEmpty);
    });

    test('Não tomei registra como não tomada', () async {
      final r = await tocarBotao(acao: acaoNaoTomei);

      expect(r.registros, [('token-salvo', 3, false)]);
    });

    test('sem login no aparelho, avisa que não registrou', () async {
      final r = await tocarBotao(acao: acaoTomei, token: null);

      expect(r.registros, isEmpty);
      expect(r.falhas, [
        'Não foi possível registrar|A dose de Losartana das 14:00 não foi '
            'marcada. Abra o MedTrack para registrar.',
      ]);
    });

    test('se o servidor recusar ou sem internet, avisa', () async {
      final r = await tocarBotao(
        acao: acaoTomei,
        erro: const ApiException('Sem conexão com o servidor.', 0),
      );

      expect(r.avisados, isEmpty);
      expect(r.falhas, hasLength(1));
    });

    test('tocar no corpo do aviso (sem botão) não registra nada', () async {
      final r = await tocarBotao(acao: null);

      expect(r.registros, isEmpty);
      expect(r.falhas, isEmpty);
    });
  });
}
