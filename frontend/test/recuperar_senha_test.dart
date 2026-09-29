import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/features/auth/recuperar_senha/solicitar_codigo_screen.dart';

class _AuthFake extends AuthRepository {
  final ApiException? erroSolicitar;
  final ApiException? erroVerificar;

  int codigosSolicitados = 0;
  String? codigoVerificado;
  Map<String, String>? redefinicao;

  _AuthFake({this.erroSolicitar, this.erroVerificar});

  @override
  Future<void> solicitarCodigo(String email) async {
    codigosSolicitados++;
    if (erroSolicitar != null) throw erroSolicitar!;
  }

  @override
  Future<void> verificarCodigo(String email, String codigo) async {
    if (erroVerificar != null) throw erroVerificar!;
    codigoVerificado = codigo;
  }

  @override
  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    redefinicao = {'email': email, 'codigo': codigo, 'novaSenha': novaSenha};
  }
}

Future<void> _abrir(WidgetTester tester, AuthRepository auth) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SolicitarCodigoScreen(authRepository: auth),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto);
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fluxo completo: e-mail, código, nova senha e volta', (
    tester,
  ) async {
    final auth = _AuthFake();
    await _abrir(tester, auth);

    await tester.enterText(find.byType(TextFormField), 'm@m.com');
    await _tocar(tester, 'Enviar código');

    expect(find.textContaining('m@m.com', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '123456');
    await _tocar(tester, 'Confirmar código');

    await tester.enterText(find.byType(TextFormField).at(0), 'novaSenha1');
    await tester.enterText(find.byType(TextFormField).at(1), 'novaSenha1');
    await _tocar(tester, 'Redefinir senha');

    expect(auth.codigoVerificado, '123456');
    expect(auth.redefinicao, {
      'email': 'm@m.com',
      'codigo': '123456',
      'novaSenha': 'novaSenha1',
    });
    expect(find.text('abrir'), findsOneWidget);
    expect(
      find.text('Senha redefinida! Entre com a nova senha.'),
      findsOneWidget,
    );
  });

  testWidgets('mostra o erro quando o e-mail não existe', (tester) async {
    await _abrir(
      tester,
      _AuthFake(
        erroSolicitar: const ApiException('E-mail não encontrado!', 404),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'x@x.com');
    await _tocar(tester, 'Enviar código');

    expect(find.text('E-mail não encontrado!'), findsOneWidget);
    expect(find.text('Confirmar código'), findsNothing);
  });

  testWidgets('não aceita código com menos de 6 dígitos', (tester) async {
    final auth = _AuthFake();
    await _abrir(tester, auth);

    await tester.enterText(find.byType(TextFormField), 'm@m.com');
    await _tocar(tester, 'Enviar código');

    await tester.enterText(find.byType(TextFormField), '123');
    await _tocar(tester, 'Confirmar código');

    expect(find.text('O código tem 6 dígitos'), findsOneWidget);
    expect(auth.codigoVerificado, isNull);
  });

  testWidgets('mostra o erro de código inválido vindo da API', (tester) async {
    await _abrir(
      tester,
      _AuthFake(erroVerificar: const ApiException('Código inválido!', 400)),
    );

    await tester.enterText(find.byType(TextFormField), 'm@m.com');
    await _tocar(tester, 'Enviar código');
    await tester.enterText(find.byType(TextFormField), '999999');
    await _tocar(tester, 'Confirmar código');

    expect(find.text('Código inválido!'), findsOneWidget);
    expect(find.text('Redefinir senha'), findsNothing);
  });

  testWidgets('reenviar código pede um novo código', (tester) async {
    final auth = _AuthFake();
    await _abrir(tester, auth);

    await tester.enterText(find.byType(TextFormField), 'm@m.com');
    await _tocar(tester, 'Enviar código');
    await _tocar(tester, 'Reenviar código');

    expect(auth.codigosSolicitados, 2);
    expect(
      find.text('Enviamos um novo código para o seu e-mail.'),
      findsOneWidget,
    );
  });

  testWidgets('acusa senhas diferentes na nova senha', (tester) async {
    final auth = _AuthFake();
    await _abrir(tester, auth);

    await tester.enterText(find.byType(TextFormField), 'm@m.com');
    await _tocar(tester, 'Enviar código');
    await tester.enterText(find.byType(TextFormField), '123456');
    await _tocar(tester, 'Confirmar código');

    await tester.enterText(find.byType(TextFormField).at(0), 'novaSenha1');
    await tester.enterText(find.byType(TextFormField).at(1), 'outraSenha');
    await _tocar(tester, 'Redefinir senha');

    expect(find.text('As senhas não coincidem'), findsOneWidget);
    expect(auth.redefinicao, isNull);
  });

  testWidgets('o login abre a recuperação com o e-mail já preenchido', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authRepository: _AuthFake())),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'm@m.com');
    await _tocar(tester, 'Esqueci minha senha');

    expect(find.text('Esqueceu sua senha?'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'm@m.com'), findsOneWidget);
  });
}
