import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/compartilhamento/compartilhamento.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  group('paciente', () {
    testWidgets('gera o código no detalhe do tratamento e deixa copiar', (
      tester,
    ) async {
      // Área de transferência do sistema simulada.
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.setData') {
            copiado = (chamada.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final compartilhamentos = CompartilhamentoFake();
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        tratamentos: TratamentoFake([tratamentoExemplo(id: 7)]),
        compartilhamentos: compartilhamentos,
        rota: Rotas.tratamento(7),
      );

      await tocar(tester, 'Compartilhar com profissional');

      expect(compartilhamentos.codigosGerados, [7]);
      expect(find.text('Código de compartilhamento'), findsOneWidget);
      expect(find.text('cod-abc123'), findsOneWidget);
      expect(find.text('Para: Amoxicilina'), findsOneWidget);

      await tocar(tester, 'Copiar código');
      expect(copiado, 'cod-abc123');
      expect(find.text('Código copiado!'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Concluir'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Código de compartilhamento'), findsNothing);
    });

    testWidgets('não oferece compartilhar um tratamento cancelado', (
      tester,
    ) async {
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        tratamentos: TratamentoFake([
          tratamentoExemplo(status: StatusTratamento.cancelado),
        ]),
        rota: Rotas.tratamento(1),
      );

      expect(find.text('Compartilhar com profissional'), findsNothing);
    });

    testWidgets('pedido de acesso aparece no Início e é aprovado', (
      tester,
    ) async {
      final compartilhamentos = CompartilhamentoFake(
        pedidos: const [
          PedidoDeAcesso(
            compartilhamentoId: 5,
            medicamento: 'Losartana',
            profissional: profissionalAna,
          ),
        ],
        doPaciente: const [
          CompartilhamentoDoPaciente(
            id: 5,
            tratamentoId: 1,
            medicamento: 'Losartana',
            profissional: profissionalAna,
            status: StatusCompartilhamento.aguardandoAprovacao,
          ),
        ],
      );
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        compartilhamentos: compartilhamentos,
        rota: Rotas.inicio,
      );

      expect(find.text('Pedido de acesso'), findsOneWidget);
      expect(
        find.text('Dra. Ana quer acompanhar seu tratamento de Losartana.'),
        findsOneWidget,
      );

      await tocar(tester, 'Ver ›');
      expect(find.text('Pedidos de acesso (1)'), findsOneWidget);
      expect(find.text('Médico(a) · CRM 12345/PB'), findsOneWidget);

      await tocar(tester, 'Aprovar');
      expect(compartilhamentos.decisoes, [(id: 5, aprovar: true)]);
      expect(find.text('Dra. Ana agora acompanha Losartana.'), findsOneWidget);
      expect(find.text('Com acesso'), findsOneWidget);
      expect(find.text('Pedidos de acesso (1)'), findsNothing);

      // De volta ao Início, o aviso some.
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido de acesso'), findsNothing);
    });

    testWidgets('recusa um pedido', (tester) async {
      final compartilhamentos = CompartilhamentoFake(
        pedidos: const [
          PedidoDeAcesso(
            compartilhamentoId: 5,
            medicamento: 'Losartana',
            profissional: profissionalAna,
          ),
        ],
      );
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        compartilhamentos: compartilhamentos,
        rota: Rotas.compartilhamentos,
      );

      await tocar(tester, 'Recusar');

      expect(compartilhamentos.decisoes, [(id: 5, aprovar: false)]);
      expect(find.text('Pedido recusado.'), findsOneWidget);
    });

    testWidgets('tira o acesso de um profissional depois de confirmar', (
      tester,
    ) async {
      final compartilhamentos = CompartilhamentoFake(
        doPaciente: const [
          CompartilhamentoDoPaciente(
            id: 3,
            tratamentoId: 1,
            medicamento: 'Losartana',
            profissional: profissionalAna,
            status: StatusCompartilhamento.ativo,
          ),
        ],
      );
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        compartilhamentos: compartilhamentos,
        rota: Rotas.compartilhamentos,
      );

      expect(find.text('acompanha: Losartana'), findsOneWidget);
      await tocar(tester, 'Tirar acesso');
      expect(find.text('Dra. Ana deixa de ver Losartana.'), findsOneWidget);

      // Voltar não tira nada.
      await tocar(tester, 'Voltar');
      expect(compartilhamentos.revogados, isEmpty);

      await tocar(tester, 'Tirar acesso');
      await tester.tap(find.widgetWithText(TextButton, 'Tirar acesso').last);
      await tester.pumpAndSettle();

      expect(compartilhamentos.revogados, [3]);
      expect(find.text('Acesso retirado.'), findsOneWidget);
      expect(find.text('Encerrados (1)'), findsOneWidget);
    });

    testWidgets('sem compartilhamentos explica como começar', (tester) async {
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        rota: Rotas.compartilhamentos,
      );

      expect(
        find.textContaining('Nenhum profissional acompanha'),
        findsOneWidget,
      );
    });

    testWidgets('o Perfil do paciente tem o item Compartilhamentos', (
      tester,
    ) async {
      await abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        rota: Rotas.perfil,
      );

      expect(find.text('Compartilhamentos'), findsOneWidget);
    });
  });

  group('profissional', () {
    final hoje = DateTime.now();

    TratamentoDePaciente compartilhado({
      int id = 10,
      String paciente = 'Maria',
      int pacienteId = 1,
      String medicamento = 'Losartana',
    }) => TratamentoDePaciente(
      compartilhamentoId: id,
      pacienteId: pacienteId,
      pacienteNome: paciente,
      tratamento: tratamentoExemplo(id: id, medicamento: medicamento),
    );

    Future<void> abrirComoProfissional(
      WidgetTester tester,
      CompartilhamentoFake compartilhamentos, {
      String rota = Rotas.inicio,
    }) => abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora, usuario: draAna),
      compartilhamentos: compartilhamentos,
      rota: rota,
    ).then((_) {});

    testWidgets('o menu tem só Pacientes e Perfil', (tester) async {
      await abrirComoProfissional(tester, CompartilhamentoFake());

      expect(find.text('Pacientes'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Tratamentos'), findsNothing);
      expect(find.text('Histórico'), findsNothing);
      expect(find.text('Seu tratamento de hoje:'), findsNothing);
      expect(find.text('Meus pacientes:'), findsOneWidget);
    });

    testWidgets('sem pacientes explica como adicionar', (tester) async {
      await abrirComoProfissional(tester, CompartilhamentoFake());

      expect(find.textContaining('Nenhum paciente ainda.'), findsOneWidget);
    });

    testWidgets('lista os tratamentos agrupados por paciente', (tester) async {
      await abrirComoProfissional(
        tester,
        CompartilhamentoFake(
          doProfissional: [
            compartilhado(id: 1, paciente: 'Maria', medicamento: 'Losartana'),
            compartilhado(
              id: 2,
              paciente: 'João',
              pacienteId: 2,
              medicamento: 'Metformina',
            ),
            compartilhado(id: 3, paciente: 'Maria', medicamento: 'Insulina'),
          ],
        ),
      );

      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('João'), findsOneWidget);
      expect(find.text('Losartana'), findsOneWidget);
      expect(find.text('Metformina'), findsOneWidget);
      expect(find.text('Insulina'), findsOneWidget);
      // Em ordem alfabética: João antes de Maria.
      expect(
        tester.getTopLeft(find.text('João')).dy,
        lessThan(tester.getTopLeft(find.text('Maria')).dy),
      );
    });

    testWidgets('adiciona um paciente pelo código', (tester) async {
      final compartilhamentos = CompartilhamentoFake();
      await abrirComoProfissional(tester, compartilhamentos);

      await tocar(tester, 'Adicionar paciente');
      await tocar(tester, 'Enviar pedido');
      expect(find.text('Informe o código.'), findsOneWidget);
      expect(compartilhamentos.codigosUsados, isEmpty);

      await tester.enterText(find.byType(TextFormField), '  cod-abc123 ');
      await tocar(tester, 'Enviar pedido');

      expect(compartilhamentos.codigosUsados, ['cod-abc123']);
      expect(find.text('Pedido enviado!'), findsOneWidget);

      await tocar(tester, 'Entendi');
      expect(find.text('Meus pacientes:'), findsOneWidget);
    });

    testWidgets('código inválido mostra o erro do servidor', (tester) async {
      final compartilhamentos = CompartilhamentoFake()
        ..erroUsar = const ApiException('Código inválido ou já utilizado.', 400);
      await abrirComoProfissional(
        tester,
        compartilhamentos,
        rota: Rotas.adicionarPaciente,
      );

      await tester.enterText(find.byType(TextFormField), 'errado');
      await tocar(tester, 'Enviar pedido');

      expect(find.text('Código inválido ou já utilizado.'), findsOneWidget);
      expect(find.text('Pedido enviado!'), findsNothing);
    });

    testWidgets('abre o tratamento do paciente só para ver', (tester) async {
      final tratamento = tratamentoExemplo(id: 10, medicamento: 'Losartana');
      Dose dose(int id, Duration atras, StatusDose status) => doseExemplo(
        id: id,
        tratamentoId: 10,
        medicamento: 'Losartana',
        em: hoje.subtract(atras),
        status: status,
      );

      await abrirComoProfissional(
        tester,
        CompartilhamentoFake(
          doProfissional: [compartilhado()],
          detalhes: {
            10: DetalheCompartilhado(
              pacienteNome: 'Maria',
              tratamento: tratamento,
              doses: [
                // Futura: ainda não aparece no registro.
                dose(4, const Duration(hours: -3), StatusDose.pendente),
                // Chegou a hora e a paciente não marcou.
                dose(3, const Duration(minutes: 30), StatusDose.pendente),
                dose(2, const Duration(days: 1), StatusDose.tomada),
                dose(1, const Duration(days: 2), StatusDose.naoTomada),
              ],
            ),
          },
        ),
      );

      await tester.tap(find.text('Losartana'));
      await tester.pumpAndSettle();

      expect(find.text('Tratamento do paciente'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('1 de 4 doses tomadas'), 200);
      await tester.scrollUntilVisible(find.text('Registro de doses'), 200);
      await tester.scrollUntilVisible(find.text('Não tomada'), 200);
      expect(find.text('Tomada'), findsOneWidget);
      expect(find.text('Não tomada'), findsOneWidget);
      // Sem botões para registrar nem atalho para o histórico do paciente.
      expect(find.text('Tomei'), findsNothing);
      expect(find.text('Ver no histórico'), findsNothing);
      expect(find.text('aguardando'), findsNothing);
    });

    testWidgets('o Perfil do profissional não tem Compartilhamentos', (
      tester,
    ) async {
      await abrirComoProfissional(
        tester,
        CompartilhamentoFake(),
        rota: Rotas.perfil,
      );

      expect(find.text('Compartilhamentos'), findsNothing);
    });
  });
}
