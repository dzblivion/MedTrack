import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Future<AuthFake> abrirPerfil(WidgetTester tester) async {
    final auth = AuthFake();
    await abrirApp(
      tester,
      auth: auth,
      storage: storageComSessao(daquiUmaHora),
      rota: Rotas.perfil,
    );
    return auth;
  }

  testWidgets('mostra os dados da conta e as configurações', (tester) async {
    await abrirPerfil(tester);

    expect(find.text('Maria'), findsNWidgets(2));
    expect(find.text('m@m.com'), findsNWidgets(2));
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Alterar senha'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
  });

  testWidgets('Termos de uso e Privacidade abrem e voltam', (tester) async {
    await abrirPerfil(tester);

    await tocar(tester, 'Termos de uso');
    expect(find.text('Não substitui orientação médica'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tocar(tester, 'Privacidade e dados');
    expect(find.text('Dados que coletamos'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Dados pessoais'), findsOneWidget);
  });

  testWidgets('Editar perfil e Notificações ainda mostram "Em breve"', (
    tester,
  ) async {
    await abrirPerfil(tester);

    await tocar(tester, 'Notificações');
    expect(find.text('Em breve.'), findsOneWidget);
  });

  testWidgets('Alterar senha usa o código por e-mail e volta ao Perfil', (
    tester,
  ) async {
    final auth = await abrirPerfil(tester);

    await tocar(tester, 'Alterar senha');
    expect(find.text('Alterar senha'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'm@m.com'), findsOneWidget);

    await tocar(tester, 'Enviar código');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tocar(tester, 'Confirmar código');
    await tester.enterText(find.byType(TextFormField).at(0), 'novaSenha1');
    await tester.enterText(find.byType(TextFormField).at(1), 'novaSenha1');
    await tocar(tester, 'Redefinir senha');

    expect(auth.redefinicao?['email'], 'm@m.com');
    expect(find.text('Senha alterada!'), findsOneWidget);
    expect(find.text('Dados pessoais'), findsOneWidget);
  });

  testWidgets('em Alterar senha, a seta volta passo a passo até o Perfil', (
    tester,
  ) async {
    await abrirPerfil(tester);

    await tocar(tester, 'Alterar senha');
    await tocar(tester, 'Enviar código');
    expect(find.text('Verifique seu e-mail'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Alterar senha'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Dados pessoais'), findsOneWidget);
  });

  testWidgets('no cadastro, os links abrem os Termos e a Privacidade', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await abrirApp(tester, rota: Rotas.cadastro);

    await tester.tapOnText(find.textRange.ofSubstring('Termos de Uso'));
    await tester.pumpAndSettle();
    expect(find.text('Não substitui orientação médica'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring('Política de Privacidade'));
    await tester.pumpAndSettle();
    expect(find.text('Dados que coletamos'), findsOneWidget);
  });
}
