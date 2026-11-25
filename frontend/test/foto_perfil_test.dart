import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/perfil/ajustar_foto_screen.dart';
import 'package:frontend/widgets/avatar_usuario.dart';

import 'helpers.dart';

void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));

  Finder fotoNoAvatar() => find.descendant(
        of: find.byType(AvatarUsuario),
        matching: find.byType(Image),
      );

  /// Abre o app no Perfil. [origens] guarda de onde a foto foi escolhida
  /// (true = câmera); [ajustada] é o que o "Ajustar foto" devolve.
  Future<void> abrir(
    WidgetTester tester, {
    required FotoPerfilFake fotos,
    String rota = Rotas.perfil,
    bool escolheAlguma = true,
    List<bool>? origens,
    Uint8List? Function(Uint8List foto)? ajustada,
  }) =>
      abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        fotoPerfil: fotos,
        escolherFoto: ({required camera}) async {
          origens?.add(camera);
          return escolheAlguma ? (bytes: pngDeTeste, nome: 'x.png') : null;
        },
        ajustarFoto: (context, foto) async => (ajustada ?? (f) => f)(foto),
        rota: rota,
      );

  Future<void> abrirMenuDaFoto(WidgetTester tester) async {
    // O selo de câmera do avatar (só aparece no Perfil).
    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('sem foto, o avatar mostra a inicial', (tester) async {
    await abrir(tester, fotos: FotoPerfilFake(), rota: Rotas.inicio);

    expect(find.text('M'), findsOneWidget);
    expect(fotoNoAvatar(), findsNothing);
  });

  testWidgets('com foto, ela aparece no avatar das abas', (tester) async {
    await abrir(tester, fotos: FotoPerfilFake(pngDeTeste), rota: Rotas.inicio);

    expect(fotoNoAvatar(), findsOneWidget);
    expect(find.text('M'), findsNothing);

    await tocar(tester, 'Tratamentos');
    expect(fotoNoAvatar(), findsOneWidget);
  });

  testWidgets('escolher da galeria, ajustar e enviar só o recorte', (
    tester,
  ) async {
    final fotos = FotoPerfilFake();
    final origens = <bool>[];
    final ajustes = <Uint8List>[];
    await abrir(
      tester,
      fotos: fotos,
      origens: origens,
      ajustada: (foto) {
        ajustes.add(foto);
        return pngDeTeste;
      },
    );

    await abrirMenuDaFoto(tester);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
    // Sem foto, não há o que remover.
    expect(find.text('Remover foto'), findsNothing);

    await tocar(tester, 'Escolher da galeria');

    // A foto escolhida passou pelo "Ajustar foto" antes de ser enviada.
    expect(origens, [false]);
    expect(ajustes, hasLength(1));
    expect(fotos.enviadas, ['foto.png']);
    expect(find.text('Foto de perfil atualizada!'), findsOneWidget);
    expect(fotoNoAvatar(), findsOneWidget);
  });

  testWidgets('tirar foto usa a câmera', (tester) async {
    final origens = <bool>[];
    await abrir(tester, fotos: FotoPerfilFake(), origens: origens);

    await abrirMenuDaFoto(tester);
    await tocar(tester, 'Tirar foto');

    expect(origens, [true]);
  });

  testWidgets('desistir de escolher não envia nada', (tester) async {
    final fotos = FotoPerfilFake();
    await abrir(tester, fotos: fotos, escolheAlguma: false);

    await abrirMenuDaFoto(tester);
    await tocar(tester, 'Escolher da galeria');

    expect(fotos.enviadas, isEmpty);
    expect(fotoNoAvatar(), findsNothing);
  });

  testWidgets('cancelar o ajuste não envia nada', (tester) async {
    final fotos = FotoPerfilFake();
    await abrir(tester, fotos: fotos, ajustada: (_) => null);

    await abrirMenuDaFoto(tester);
    await tocar(tester, 'Escolher da galeria');

    expect(fotos.enviadas, isEmpty);
  });

  testWidgets('remover a foto volta para a inicial', (tester) async {
    final fotos = FotoPerfilFake(pngDeTeste);
    await abrir(tester, fotos: fotos);
    expect(fotoNoAvatar(), findsOneWidget);

    await abrirMenuDaFoto(tester);
    await tocar(tester, 'Remover foto');

    expect(fotos.remocoes, 1);
    expect(find.text('Foto removida.'), findsOneWidget);
    expect(fotoNoAvatar(), findsNothing);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('trocar de novo cedo demais mostra o aviso do backend', (
    tester,
  ) async {
    final fotos = FotoPerfilFake()
      ..erroEnviar = const ApiException(
        'Aguarde antes de trocar a foto novamente.',
        429,
      );
    await abrir(tester, fotos: fotos);

    await abrirMenuDaFoto(tester);
    await tocar(tester, 'Escolher da galeria');

    expect(
      find.text('Aguarde antes de trocar a foto novamente.'),
      findsOneWidget,
    );
    expect(fotoNoAvatar(), findsNothing);
  });

  testWidgets('ao sair da conta, a foto é esquecida', (tester) async {
    final sessao = await abrirApp(
      tester,
      storage: storageComSessao(daquiUmaHora),
      fotoPerfil: FotoPerfilFake(pngDeTeste),
      rota: Rotas.perfil,
    );
    expect(fotoNoAvatar(), findsOneWidget);

    await sessao.sair();
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(fotoNoAvatar(), findsNothing);
  });

  testWidgets('a tela Ajustar foto devolve a foto recortada', (tester) async {
    Uint8List? resultado;
    var voltou = false;

    // Abrir e recortar imagens é trabalho de verdade (não simulado), por
    // isso roda fora do relógio falso dos testes.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await ajustarFotoNaTela(context, pngDeTeste);
                voltou = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      for (var i = 0; i < 20 && find.text('Usar foto').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Ajustar foto'), findsOneWidget);
    expect(find.text('Arraste e aproxime para encaixar no círculo.'),
        findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Usar foto'));
      for (var i = 0; i < 20 && !voltou; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(voltou, isTrue);
    // Um PNG de verdade (começa com a assinatura do formato).
    expect(resultado?.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
