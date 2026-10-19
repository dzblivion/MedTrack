import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';

import 'helpers.dart';

void main() {
  testWidgets('mostra campos e botão de entrar', (tester) async {
    await abrirApp(tester, rota: Rotas.login);

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('valida campos vazios antes de chamar a API', (tester) async {
    final auth = AuthFake();
    await abrirApp(tester, auth: auth, rota: Rotas.login);

    await tocar(tester, 'Entrar');

    expect(find.text('Informe seu e-mail'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
    expect(auth.chamadasLogin, 0);
  });

  testWidgets('exibe a mensagem de erro devolvida pela API', (tester) async {
    await abrirApp(
      tester,
      auth: AuthFake(
        respostaLogin: () async =>
            throw const ApiException('E-mail ou senha incorretos!', 401),
      ),
      rota: Rotas.login,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tocar(tester, 'Entrar');

    expect(find.text('E-mail ou senha incorretos!'), findsOneWidget);
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('login certo guarda a sessão e abre o Início', (tester) async {
    final storage = StorageMemoria();
    final api = ApiClient();
    await abrirApp(
      tester,
      api: api,
      storage: storage,
      auth: AuthFake(
        respostaLogin: () async => (token: 'token-da-maria', usuario: maria),
      ),
      rota: Rotas.login,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'm@m.com');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tocar(tester, 'Entrar');

    expect(find.text('Olá, Maria!'), findsOneWidget);
    expect(storage.salva?.token, 'token-da-maria');
    expect(api.token, 'token-da-maria');
  });
}
