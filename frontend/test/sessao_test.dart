import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));
  final ontem = DateTime.now().subtract(const Duration(days: 1));

  testWidgets('com sessão válida salva, o app abre direto no Início', (
    tester,
  ) async {
    await abrirApp(tester, storage: storageComSessao(daquiUmaHora));

    expect(find.text('Olá, Maria!'), findsOneWidget);
    expect(find.text('Começar'), findsNothing);
  });

  testWidgets('sessão vencida é descartada e o app abre na Splash', (
    tester,
  ) async {
    final storage = storageComSessao(ontem);
    await abrirApp(tester, storage: storage);

    expect(find.text('Começar'), findsOneWidget);
    expect(storage.salva, isNull);
  });

  testWidgets('sem login, abrir uma tela do app leva para o login', (
    tester,
  ) async {
    await abrirApp(tester, rota: Rotas.tratamentos);

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('logado, abrir o login leva para o Início', (tester) async {
    await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      rota: Rotas.login,
    );

    expect(find.text('Olá, Maria!'), findsOneWidget);
  });

  testWidgets('o menu de baixo troca de aba', (tester) async {
    await abrirApp(tester, storage: storageComSessao(daquiUmaHora));

    await tocar(tester, 'Tratamentos');
    expect(find.text('Em construção'), findsOneWidget);
    expect(find.text('Olá, Maria!'), findsNothing);

    await tocar(tester, 'Início');
    expect(find.text('Olá, Maria!'), findsOneWidget);
  });

  testWidgets('Sair da conta apaga a sessão e volta para o login', (
    tester,
  ) async {
    final storage = storageComSessao(daquiUmaHora);
    final sessao = await abrirApp(tester, storage: storage);

    await tocar(tester, 'Perfil');
    await tocar(tester, 'Sair da conta');

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(storage.salva, isNull);
    expect(sessao.logado, isFalse);
  });
}
