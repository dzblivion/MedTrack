import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/auth/cadastro_screen.dart';

class _AuthFake extends AuthRepository {
  bool chamouUsuario = false;
  bool chamouProfissional = false;

  @override
  Future<void> cadastrarUsuario({
    required String nome,
    required String email,
    required String senha,
  }) async {
    chamouUsuario = true;
  }

  @override
  Future<void> cadastrarProfissional({
    required String nome,
    required String email,
    required String senha,
    required String profissao,
    required String registro,
    required String ufRegistro,
  }) async {
    chamouProfissional = true;
  }
}

void main() {
  Future<void> abrirCadastro(WidgetTester tester, AuthRepository auth) async {
    // Tamanho de um iPhone comum, para testar a rolagem em condição real
    // (o modo profissional tem campos demais para caber numa tela só).
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CadastroScreen(authRepository: auth),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os campos básicos e esconde os de profissional', (
    tester,
  ) async {
    await abrirCadastro(tester, _AuthFake());

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
    await abrirCadastro(tester, _AuthFake());

    await tester.tap(find.text('Profissional'));
    await tester.pumpAndSettle();

    expect(find.text('Profissão'), findsOneWidget);
    expect(find.text('Número do registro'), findsOneWidget);
    expect(find.text('UF do registro'), findsOneWidget);
  });

  testWidgets('não envia se os termos não foram aceitos', (tester) async {
    final auth = _AuthFake();
    await abrirCadastro(tester, auth);

    await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
    await tester.enterText(find.byType(TextFormField).at(1), 'm@m.com');
    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.enterText(find.byType(TextFormField).at(3), '12345678');

    final botao = find.text('Criar minha conta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pump();

    expect(auth.chamouUsuario, isFalse);
    expect(
      find.text('Você precisa aceitar os termos para continuar.'),
      findsOneWidget,
    );
  });

  testWidgets('acusa senhas diferentes', (tester) async {
    await abrirCadastro(tester, _AuthFake());

    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'outraSenha');

    final botao = find.text('Criar minha conta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pump();

    expect(find.text('As senhas não coincidem'), findsOneWidget);
  });

  testWidgets('cadastra usuário comum e volta para a tela anterior', (
    tester,
  ) async {
    final auth = _AuthFake();
    await abrirCadastro(tester, auth);

    await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
    await tester.enterText(find.byType(TextFormField).at(1), 'm@m.com');
    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.enterText(find.byType(TextFormField).at(3), '12345678');

    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);

    final botao = find.text('Criar minha conta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(auth.chamouUsuario, isTrue);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('cadastra profissional com os campos extras', (tester) async {
    final auth = _AuthFake();
    await abrirCadastro(tester, auth);

    await tester.tap(find.text('Profissional'));
    await tester.pumpAndSettle();

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

    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);

    final botao = find.text('Criar minha conta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(auth.chamouProfissional, isTrue);
  });
}
