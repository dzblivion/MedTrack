import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';

import 'helpers.dart';

void main() {
  Future<void> ateTelaDoCodigo(WidgetTester tester, AuthFake auth) async {
    await abrirApp(tester, auth: auth, rota: Rotas.recuperarSenha);
    await tester.enterText(find.byType(TextFormField), 'm@m.com');
    await tocar(tester, 'Enviar código');
  }

  testWidgets('fluxo completo: e-mail, código, nova senha e volta ao login', (
    tester,
  ) async {
    final auth = AuthFake();
    await ateTelaDoCodigo(tester, auth);

    expect(find.textContaining('m@m.com', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '123456');
    await tocar(tester, 'Confirmar código');

    await tester.enterText(find.byType(TextFormField).at(0), 'novaSenha1');
    await tester.enterText(find.byType(TextFormField).at(1), 'novaSenha1');
    await tocar(tester, 'Redefinir senha');

    expect(auth.codigoVerificado, '123456');
    expect(auth.redefinicao, {
      'email': 'm@m.com',
      'codigo': '123456',
      'novaSenha': 'novaSenha1',
    });
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(
      find.text('Senha redefinida! Entre com a nova senha.'),
      findsOneWidget,
    );
  });

  testWidgets('mostra o erro quando o servidor falha ao pedir o código', (
    tester,
  ) async {
    const mensagem = 'Não foi possível processar a recuperação de senha!';
    await ateTelaDoCodigo(
      tester,
      AuthFake(erroSolicitar: const ApiException(mensagem, 500)),
    );

    expect(find.text(mensagem), findsOneWidget);
    expect(find.text('Confirmar código'), findsNothing);
  });

  testWidgets('não aceita código com menos de 6 dígitos', (tester) async {
    final auth = AuthFake();
    await ateTelaDoCodigo(tester, auth);

    await tester.enterText(find.byType(TextFormField), '123');
    await tocar(tester, 'Confirmar código');

    expect(find.text('O código tem 6 dígitos'), findsOneWidget);
    expect(auth.codigoVerificado, isNull);
  });

  testWidgets('mostra o erro de código inválido vindo da API', (tester) async {
    await ateTelaDoCodigo(
      tester,
      AuthFake(erroVerificar: const ApiException('Código inválido!', 400)),
    );

    await tester.enterText(find.byType(TextFormField), '999999');
    await tocar(tester, 'Confirmar código');

    expect(find.text('Código inválido!'), findsOneWidget);
    expect(find.text('Redefinir senha'), findsNothing);
  });

  testWidgets('reenviar código pede um novo código', (tester) async {
    final auth = AuthFake();
    await ateTelaDoCodigo(tester, auth);

    await tocar(tester, 'Reenviar código');

    expect(auth.codigosSolicitados, 2);
    expect(
      find.text('Enviamos um novo código para o seu e-mail.'),
      findsOneWidget,
    );
  });

  testWidgets('acusa senhas diferentes na nova senha', (tester) async {
    final auth = AuthFake();
    await ateTelaDoCodigo(tester, auth);
    await tester.enterText(find.byType(TextFormField), '123456');
    await tocar(tester, 'Confirmar código');

    await tester.enterText(find.byType(TextFormField).at(0), 'novaSenha1');
    await tester.enterText(find.byType(TextFormField).at(1), 'outraSenha');
    await tocar(tester, 'Redefinir senha');

    expect(find.text('As senhas não coincidem'), findsOneWidget);
    expect(auth.redefinicao, isNull);
  });

  testWidgets('o login abre a recuperação com o e-mail já preenchido', (
    tester,
  ) async {
    await abrirApp(tester, rota: Rotas.login);

    await tester.enterText(find.byType(TextFormField).at(0), 'm@m.com');
    await tocar(tester, 'Esqueci minha senha');

    expect(find.text('Esqueceu sua senha?'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'm@m.com'), findsOneWidget);
  });

  testWidgets('abrir a tela do código sem passar pelo e-mail recomeça o fluxo', (
    tester,
  ) async {
    await abrirApp(tester, rota: Rotas.verificarCodigo);

    expect(find.text('Esqueceu sua senha?'), findsOneWidget);
  });
}
