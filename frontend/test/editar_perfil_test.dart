import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/auth/usuario.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<({ContaFake conta, StorageMemoria storage})> abrirEdicao(
    WidgetTester tester, {
    ContaFake? conta,
  }) async {
    final contaUsada = conta ?? ContaFake();
    final storage = storageComSessao(daquiUmaHora);
    await abrirApp(
      tester,
      storage: storage,
      conta: contaUsada,
      rota: Rotas.perfil,
    );
    await tocar(tester, 'Editar perfil');
    return (conta: contaUsada, storage: storage);
  }

  Finder campoNome() => find.byType(TextFormField);

  group('editar perfil', () {
    testWidgets('abre com o nome atual e o e-mail só para ver', (tester) async {
      await abrirEdicao(tester);

      expect(find.widgetWithText(TextFormField, 'Maria'), findsOneWidget);
      expect(find.text('m@m.com'), findsOneWidget);
      expect(
        find.text('O e-mail é usado para entrar e não pode ser alterado.'),
        findsOneWidget,
      );
    });

    testWidgets('salva o nome novo, atualiza o Perfil e o que fica salvo', (
      tester,
    ) async {
      final (:conta, :storage) = await abrirEdicao(tester);

      await tester.enterText(campoNome(), '  Maria Souza ');
      await tocar(tester, 'Salvar');

      expect(conta.nomesSalvos, ['Maria Souza']);
      expect(find.text('Nome atualizado.'), findsOneWidget);
      // De volta ao Perfil, já com o nome novo.
      expect(find.text('Dados pessoais'), findsOneWidget);
      expect(find.text('Maria Souza'), findsNWidgets(2));
      // Ao reabrir o app o nome continua certo.
      expect(Usuario.fromJson(storage.salva!.usuario).nome, 'Maria Souza');
    });

    testWidgets('não aceita nome vazio', (tester) async {
      final (:conta, storage: _) = await abrirEdicao(tester);

      await tester.enterText(campoNome(), '   ');
      await tocar(tester, 'Salvar');

      expect(find.text('Informe seu nome.'), findsOneWidget);
      expect(conta.nomesSalvos, isEmpty);
    });

    testWidgets('sem mudança, só volta sem chamar o servidor', (tester) async {
      final (:conta, storage: _) = await abrirEdicao(tester);

      await tocar(tester, 'Salvar');

      expect(conta.nomesSalvos, isEmpty);
      expect(find.text('Dados pessoais'), findsOneWidget);
    });

    testWidgets('mostra o erro do servidor', (tester) async {
      final conta = ContaFake()
        ..erroNome = const ApiException('Não foi possível atualizar o nome!');
      await abrirEdicao(tester, conta: conta);

      await tester.enterText(campoNome(), 'Outro Nome');
      await tocar(tester, 'Salvar');

      expect(find.text('Não foi possível atualizar o nome!'), findsOneWidget);
      expect(find.text('Editar perfil'), findsOneWidget);
    });
  });

  group('excluir conta', () {
    Future<void> abrirExclusao(WidgetTester tester) async {
      await tocar(tester, 'Excluir minha conta');
      expect(find.text('Excluir sua conta?'), findsOneWidget);
    }

    Finder campoSenha() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    Future<void> confirmar(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Excluir conta'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('senha errada avisa na janela e não exclui', (tester) async {
      final (:conta, storage: _) = await abrirEdicao(tester);
      await abrirExclusao(tester);

      await tester.enterText(campoSenha(), 'errada');
      await confirmar(tester);

      expect(find.text('Senha incorreta!'), findsOneWidget);
      expect(find.text('Excluir sua conta?'), findsOneWidget);
      expect(conta.exclusoes, 0);
    });

    testWidgets('pede a senha antes de excluir', (tester) async {
      final (:conta, storage: _) = await abrirEdicao(tester);
      await abrirExclusao(tester);

      await confirmar(tester);

      expect(find.text('Digite sua senha para confirmar.'), findsOneWidget);
      expect(conta.exclusoes, 0);
    });

    testWidgets('Cancelar fecha sem excluir', (tester) async {
      final (:conta, storage: _) = await abrirEdicao(tester);
      await abrirExclusao(tester);

      await tocar(tester, 'Cancelar');

      expect(find.text('Excluir sua conta?'), findsNothing);
      expect(conta.exclusoes, 0);
    });

    testWidgets('com a senha certa, exclui e volta para o login', (
      tester,
    ) async {
      final (:conta, :storage) = await abrirEdicao(tester);
      await abrirExclusao(tester);

      await tester.enterText(campoSenha(), 'senha123');
      await confirmar(tester);

      expect(conta.exclusoes, 1);
      expect(find.text('Sua conta foi excluída.'), findsOneWidget);
      expect(find.text('Entrar'), findsWidgets);
      expect(storage.salva, isNull);
    });
  });
}
