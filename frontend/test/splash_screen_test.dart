import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('Entrar na Splash abre o login', (tester) async {
    await abrirApp(tester);

    await tocar(tester, 'Entrar');

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('Começar abre o cadastro, e Entrar no cadastro abre o login', (
    tester,
  ) async {
    await abrirApp(tester);

    await tocar(tester, 'Começar');
    expect(find.text('Crie sua conta!'), findsOneWidget);

    await tocar(tester, 'Entrar');
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}
