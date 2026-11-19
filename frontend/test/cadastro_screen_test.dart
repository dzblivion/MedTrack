import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/auth/widgets/campo_codigo.dart';

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

  /// Preenche o cadastro de usuário e chega na tela do código.
  Future<void> chegarNoCodigo(WidgetTester tester, AuthFake auth) async {
    await abrirCadastro(tester, auth, tamanhoCelular: false);
    await preencherUsuario(tester);
    await aceitarTermos(tester);
    await tocar(tester, 'Criar minha conta');
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

  testWidgets('não pede o código se os termos não foram aceitos', (
    tester,
  ) async {
    final auth = AuthFake();
    await abrirCadastro(tester, auth);

    await preencherUsuario(tester);
    await tocar(tester, 'Criar minha conta');

    expect(auth.codigosCadastro, isEmpty);
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

  testWidgets('usuário: pede o código e só cria a conta com ele', (
    tester,
  ) async {
    final auth = AuthFake();
    await chegarNoCodigo(tester, auth);

    expect(auth.codigosCadastro, ['m@m.com']);
    expect(auth.cadastro, isNull);
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(find.textContaining('m@m.com'), findsOneWidget);

    await digitarCodigo(tester, '123456');
    await tocar(tester, 'Confirmar e criar conta');

    expect(auth.cadastro?.profissional, isFalse);
    expect(auth.cadastro?.json, {
      'nome': 'Maria',
      'email': 'm@m.com',
      'senha': '12345678',
      'codigo': '123456',
    });
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('Conta criada com sucesso! Faça login.'), findsOneWidget);
  });

  testWidgets('o código usa o teclado numérico e aceita só 6 números', (
    tester,
  ) async {
    await chegarNoCodigo(tester, AuthFake());

    final campo = tester.widget<TextField>(
      find.descendant(
        of: find.byType(CampoCodigo),
        matching: find.byType(TextField),
      ),
    );
    expect(campo.keyboardType, TextInputType.number);

    // Letras são ignoradas e o que passa de 6 dígitos é cortado.
    await digitarCodigo(tester, '12a3456789');
    await tester.pump();

    expect(campo.controller?.text, '123456');
    for (final digito in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digito), findsOneWidget);
    }
    expect(find.text('7'), findsNothing);
  });

  testWidgets('código precisa ter 6 dígitos', (tester) async {
    final auth = AuthFake();
    await chegarNoCodigo(tester, auth);

    await tocar(tester, 'Confirmar e criar conta');
    expect(find.text('Informe o código'), findsOneWidget);

    await digitarCodigo(tester, '123');
    await tocar(tester, 'Confirmar e criar conta');
    expect(find.text('O código tem 6 dígitos'), findsOneWidget);
    expect(auth.cadastro, isNull);
  });

  testWidgets('código errado mostra a mensagem e continua na tela', (
    tester,
  ) async {
    final auth = AuthFake()
      ..erroCadastrar = const ApiException('Código inválido!', 400);
    await chegarNoCodigo(tester, auth);

    await digitarCodigo(tester, '999999');
    await tocar(tester, 'Confirmar e criar conta');

    expect(find.text('Código inválido!'), findsOneWidget);
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
  });

  testWidgets('e-mail já cadastrado: avisa e fica no cadastro', (tester) async {
    final auth = AuthFake()
      ..erroCodigoCadastro = const ApiException('E-mail já cadastrado!', 409);
    await chegarNoCodigo(tester, auth);

    expect(find.text('E-mail já cadastrado!'), findsOneWidget);
    expect(find.text('Crie sua conta!'), findsOneWidget);
  });

  testWidgets('código pedido há pouco (429): segue para digitar o mesmo', (
    tester,
  ) async {
    final auth = AuthFake()
      ..erroCodigoCadastro = const ApiException(
        'Aguarde 60 segundos antes de solicitar outro código.',
        429,
      );
    await chegarNoCodigo(tester, auth);

    expect(find.text('Confirme seu e-mail'), findsOneWidget);
  });

  testWidgets('reenviar só libera depois de 60 segundos', (tester) async {
    final auth = AuthFake();
    await chegarNoCodigo(tester, auth);

    expect(find.text('Reenviar em 60s'), findsOneWidget);
    expect(find.text('Reenviar código'), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Reenviar em 30s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tocar(tester, 'Reenviar código');

    expect(auth.codigosCadastro, ['m@m.com', 'm@m.com']);
    expect(find.text('Enviamos um novo código para o seu e-mail.'), findsOneWidget);
    expect(find.text('Reenviar em 60s'), findsOneWidget);
  });

  testWidgets('voltar do código mantém o que foi preenchido', (tester) async {
    await chegarNoCodigo(tester, AuthFake());

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Crie sua conta!'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Maria'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'm@m.com'), findsOneWidget);
  });

  testWidgets('abrir a tela do código sem o cadastro volta para ele', (
    tester,
  ) async {
    await abrirApp(tester, rota: Rotas.confirmarCadastro);

    expect(find.text('Crie sua conta!'), findsOneWidget);
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

  testWidgets('profissional: envia os campos extras junto com o código', (
    tester,
  ) async {
    final auth = AuthFake();
    await abrirCadastro(tester, auth, tamanhoCelular: false);

    await tocar(tester, 'Profissional');

    await tester.enterText(find.byType(TextFormField).at(0), 'Dra. Ana');
    await tester.enterText(find.byType(TextFormField).at(1), 'ana@m.com');

    await tester.tap(find.byType(DropdownMenuFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Médico(a)').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(2), 'CRM1234');

    final dropdownUf = find.byType(DropdownMenuFormField<String>).last;
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

    await digitarCodigo(tester, '654321');
    await tocar(tester, 'Confirmar e criar conta');

    expect(auth.cadastro?.profissional, isTrue);
    expect(auth.cadastro?.json, {
      'nome': 'Dra. Ana',
      'email': 'ana@m.com',
      'senha': '12345678',
      'codigo': '654321',
      'profissao': 'Médico(a)',
      'registro': 'CRM1234',
      'uf_registro': 'AC',
    });
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}
