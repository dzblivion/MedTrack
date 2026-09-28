import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/splash/splash_screen.dart';

Future<void> _tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto);
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Entrar na Splash abre o login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    await _tocar(tester, 'Entrar');

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('Começar abre o cadastro, e Entrar no cadastro abre o login', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    await _tocar(tester, 'Começar');
    expect(find.text('Crie sua conta!'), findsOneWidget);

    await _tocar(tester, 'Entrar');
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}
