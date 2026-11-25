import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Contas do "Ajustar foto": a foto fica por baixo de um círculo de
/// [diametro] px na tela, ampliada por [zoom] (1 = só cobre o círculo) e
/// arrastada por [deslocamento] (do centro da foto ao centro do círculo).

/// Escala que faz o lado menor da foto caber exatamente no círculo.
double escalaBase(Size foto, double diametro) =>
    diametro / math.min(foto.width, foto.height);

/// Mantém a foto cobrindo o círculo inteiro (sem sobrar espaço vazio).
Offset limitarDeslocamento({
  required Size foto,
  required double diametro,
  required double zoom,
  required Offset deslocamento,
}) {
  final escala = escalaBase(foto, diametro) * zoom;
  final folgaX = (foto.width * escala - diametro) / 2;
  final folgaY = (foto.height * escala - diametro) / 2;
  return Offset(
    deslocamento.dx.clamp(-folgaX, folgaX),
    deslocamento.dy.clamp(-folgaY, folgaY),
  );
}

/// O quadrado da foto original (em pixels) que está dentro do círculo.
Rect recorteDaFoto({
  required Size foto,
  required double diametro,
  required double zoom,
  required Offset deslocamento,
}) {
  final escala = escalaBase(foto, diametro) * zoom;
  final lado = diametro / escala;
  final centro = Offset(foto.width / 2, foto.height / 2) - deslocamento / escala;
  return Rect.fromCenter(center: centro, width: lado, height: lado)
      .intersect(Offset.zero & foto);
}

/// Gera a imagem recortada (PNG quadrado, no máximo 1024 px, o tamanho que
/// o backend guarda).
Future<Uint8List> recortar(ui.Image foto, Rect recorte) async {
  final lado = math.min(recorte.shortestSide, 1024).round();
  final gravador = ui.PictureRecorder();
  Canvas(gravador).drawImageRect(
    foto,
    recorte,
    Rect.fromLTWH(0, 0, lado.toDouble(), lado.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final imagem = await gravador.endRecording().toImage(lado, lado);
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  imagem.dispose();
  return dados!.buffer.asUint8List();
}
