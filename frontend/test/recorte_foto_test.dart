import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/perfil/recorte_foto.dart';

void main() {
  // Foto deitada de 2000 x 1000 px, círculo de 200 px na tela.
  const foto = Size(2000, 1000);
  const diametro = 200.0;

  test('sem zoom e sem arrastar, recorta o quadrado do meio', () {
    final r = recorteDaFoto(
      foto: foto,
      diametro: diametro,
      zoom: 1,
      deslocamento: Offset.zero,
    );
    // O lado menor (1000) cabe no círculo: recorta 1000 x 1000 no centro.
    expect(r, const Rect.fromLTWH(500, 0, 1000, 1000));
  });

  test('com zoom 2, recorta um pedaço menor', () {
    final r = recorteDaFoto(
      foto: foto,
      diametro: diametro,
      zoom: 2,
      deslocamento: Offset.zero,
    );
    expect(r, const Rect.fromLTWH(750, 250, 500, 500));
  });

  test('arrastar a foto para a direita mostra o lado esquerdo dela', () {
    // Na tela, 1 px = 5 px da foto (200 / 1000). Arrastar 100 px = 500 px.
    final r = recorteDaFoto(
      foto: foto,
      diametro: diametro,
      zoom: 1,
      deslocamento: const Offset(100, 0),
    );
    expect(r, const Rect.fromLTWH(0, 0, 1000, 1000));
  });

  test('não deixa arrastar a ponto de sobrar espaço vazio no círculo', () {
    // A foto na tela tem 400 x 200: dá para ir 100 px para cada lado e
    // nada na vertical.
    final limitado = limitarDeslocamento(
      foto: foto,
      diametro: diametro,
      zoom: 1,
      deslocamento: const Offset(300, -50),
    );
    expect(limitado, const Offset(100, 0));
  });

  test('com zoom, a folga para arrastar aumenta', () {
    final limitado = limitarDeslocamento(
      foto: foto,
      diametro: diametro,
      zoom: 2,
      deslocamento: const Offset(1000, 1000),
    );
    // Na tela: 800 x 400 → folga de 300 na horizontal e 100 na vertical.
    expect(limitado, const Offset(300, 100));
  });
}
