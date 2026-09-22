import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/auth/login_screen.dart';

class _AuthFake extends AuthRepository {
  final Future<Usuario> Function() resposta;

  _AuthFake(this.resposta);

  @override
  Future<Usuario> login(String email, String senha) => resposta();
}

Widget _tela(AuthRepository auth) =>
    MaterialApp(home: LoginScreen(authRepository: auth));

void main() {
  testWidgets('mostra campos e botão de entrar', (tester) async {
    await tester.pumpWidget(_tela(_AuthFake(() async => throw UnimplementedError())));

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('valida campos vazios antes de chamar a API', (tester) async {
    var chamou = false;
    await tester.pumpWidget(_tela(_AuthFake(() async {
      chamou = true;
      throw UnimplementedError();
    })));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe seu e-mail'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
    expect(chamou, isFalse);
  });

  testWidgets('exibe a mensagem de erro devolvida pela API', (tester) async {
    await tester.pumpWidget(_tela(_AuthFake(
      () async => throw const ApiException('E-mail ou senha incorretos!', 401),
    )));

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('E-mail ou senha incorretos!'), findsOneWidget);
  });

  testWidgets('vai para a Home quando o login dá certo', (tester) async {
    await tester.pumpWidget(_tela(_AuthFake(
      () async => const Usuario(id: 1, nome: 'Maria', email: 'm@m.com'),
    )));

    await tester.enterText(find.byType(TextFormField).at(0), 'm@m.com');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Maria!'), findsOneWidget);
  });
}
