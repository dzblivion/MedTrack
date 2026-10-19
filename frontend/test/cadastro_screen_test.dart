import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';

import 'helpers.dart';

void main() {
  // Tamanho de um iPhone comum, para testar a rolagem em condição real
  // (o modo profissional tem campos demais para caber numa tela só).
  // Testes que terminam no login usam o tamanho padrão: a linha
  // "Ainda não tem uma conta?" não cabe em 390 px com a fonte larga dos testes.
  Future<void> abrirCadastro(
    WidgetTester tester,
    AuthFake auth, {
    bool tamanhoCelular = true,
  }) async {
    if (tamanhoCelular) {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await abrirApp(tester, auth: auth, rota: Rotas.cadastro);
  }

  Future<void> preencherUsuario(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
    await tester.enterText(find.byType(TextFormField).at(1), 'm@m.com');
    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.enterText(find.byType(TextFormField).at(3), '12345678');
  }

  Future<void> aceitarTermos(WidgetTester tester) async {
    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
  }

  testWidgets('mostra os campos básicos e esconde os de profissional', (
    tester,
  ) async {
    await abrirCadastro(tester, AuthFake());

    expect(find.text('Nome completo'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);
    expect(find.text('Profissão'), findsNothing);
    expect(find.text('Número do registro'), findsNothing);
  });

  testWidgets('alternar para Profissional revela os campos extras', (
    tester,
  ) async {
    await abrirCadastro(tester, AuthFake());

    await tocar(tester, 'Profissional');

    expect(find.text('Profissão'), findsOneWidget);
    expect(find.text('Número do registro'), findsOneWidget);
    expect(find.text('UF do registro'), findsOneWidget);
  });

  testWidgets('não envia se os termos não foram aceitos', (tester) async {
    final auth = AuthFake();
    await abrirCadastro(tester, auth);

    await preencherUsuario(tester);
    await tocar(tester, 'Criar minha conta');

    expect(auth.chamouUsuario, isFalse);
    expect(
      find.text('Você precisa aceitar os termos para continuar.'),
      findsOneWidget,
    );
  });

  testWidgets('acusa senhas diferentes', (tester) async {
    await abrirCadastro(tester, AuthFake());

    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'outraSenha');
    await tocar(tester, 'Criar minha conta');

    expect(find.text('As senhas não coincidem'), findsOneWidget);
  });

  testWidgets('cadastra usuário comum e abre o login', (tester) async {
    final auth = AuthFake();
    await abrirCadastro(tester, auth, tamanhoCelular: false);

    await preencherUsuario(tester);
    await aceitarTermos(tester);
    await tocar(tester, 'Criar minha conta');

    expect(auth.chamouUsuario, isTrue);
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('Conta criada com sucesso! Faça login.'), findsOneWidget);
  });

  testWidgets('pelo login, Criar Conta e depois Entrar volta ao login', (
    tester,
  ) async {
    await abrirApp(tester, rota: Rotas.login);

    await tocar(tester, 'Criar Conta');
    expect(find.text('Crie sua conta!'), findsOneWidget);

    await tocar(tester, 'Entrar');
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('cadastra profissional com os campos extras', (tester) async {
    final auth = AuthFake();
    await abrirCadastro(tester, auth, tamanhoCelular: false);

    await tocar(tester, 'Profissional');

    await tester.enterText(find.byType(TextFormField).at(0), 'Dra. Ana');
    await tester.enterText(find.byType(TextFormField).at(1), 'ana@m.com');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Médico(a)').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(2), 'CRM1234');

    final dropdownUf = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(dropdownUf);
    await tester.tap(dropdownUf);
    await tester.pumpAndSettle();
    final opcaoUf = find.text('AC').last;
    await tester.ensureVisible(opcaoUf);
    await tester.tap(opcaoUf);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(3), '12345678');
    await tester.enterText(find.byType(TextFormField).at(4), '12345678');
    await aceitarTermos(tester);
    await tocar(tester, 'Criar minha conta');

    expect(auth.chamouProfissional, isTrue);
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}
