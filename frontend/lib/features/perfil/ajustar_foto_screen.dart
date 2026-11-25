import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'recorte_foto.dart';

/// Abre o "Ajustar foto" por cima de tudo e devolve a foto recortada no
/// círculo (PNG), ou nulo se a pessoa cancelou.
typedef AjustarFoto = Future<Uint8List?> Function(
  BuildContext context,
  Uint8List foto,
);

Future<Uint8List?> ajustarFotoNaTela(BuildContext context, Uint8List foto) =>
    Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AjustarFotoScreen(foto: foto),
      ),
    );

/// A pessoa arrasta e aproxima a foto para encaixar o rosto no círculo,
/// que mostra exatamente como o avatar vai ficar.
class AjustarFotoScreen extends StatefulWidget {
  final Uint8List foto;

  const AjustarFotoScreen({super.key, required this.foto});

  @override
  State<AjustarFotoScreen> createState() => _AjustarFotoScreenState();
}

class _AjustarFotoScreenState extends State<AjustarFotoScreen> {
  static const _zoomMaximo = 4.0;
  static const _fonte = 'Poppins';

  ui.Image? _imagem;
  bool _falhou = false;
  bool _recortando = false;

  double _zoom = 1;
  Offset _deslocamento = Offset.zero;

  // Início do gesto de arrastar/pinçar.
  double _zoomNoInicio = 1;
  Offset _deslocamentoNoInicio = Offset.zero;
  Offset _dedoNoInicio = Offset.zero;

  /// Diâmetro do círculo na tela (calculado no layout).
  double _diametro = 0;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void dispose() {
    _imagem?.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.foto);
      final quadro = await codec.getNextFrame();
      if (!mounted) return quadro.image.dispose();
      setState(() => _imagem = quadro.image);
    } catch (_) {
      if (mounted) setState(() => _falhou = true);
    }
  }

  Size get _tamanhoFoto =>
      Size(_imagem!.width.toDouble(), _imagem!.height.toDouble());

  void _aplicar({required double zoom, required Offset deslocamento}) {
    final z = zoom.clamp(1.0, _zoomMaximo);
    setState(() {
      _zoom = z;
      _deslocamento = limitarDeslocamento(
        foto: _tamanhoFoto,
        diametro: _diametro,
        zoom: z,
        deslocamento: deslocamento,
      );
    });
  }

  Future<void> _usar() async {
    final imagem = _imagem;
    if (imagem == null) return;
    setState(() => _recortando = true);
    final recorte = recorteDaFoto(
      foto: _tamanhoFoto,
      diametro: _diametro,
      zoom: _zoom,
      deslocamento: _deslocamento,
    );
    final bytes = await recortar(imagem, recorte);
    if (mounted) Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Ajustar foto',
          style: TextStyle(fontFamily: _fonte, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _area()),
            if (_imagem != null) _controles(),
          ],
        ),
      ),
    );
  }

  Widget _area() {
    final imagem = _imagem;
    if (_falhou) {
      return const Center(
        child: Text(
          'Não foi possível abrir esta imagem.',
          style: TextStyle(fontFamily: _fonte, color: Colors.white70),
        ),
      );
    }
    if (imagem == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (context, espaco) {
        _diametro = math.min(espaco.maxWidth, espaco.maxHeight) * 0.8;
        final escala = escalaBase(_tamanhoFoto, _diametro) * _zoom;

        return Listener(
          // Rodinha do mouse (computador) também aproxima/afasta.
          onPointerSignal: (evento) {
            if (evento is PointerScrollEvent) {
              final fator = evento.scrollDelta.dy > 0 ? 0.9 : 1.1;
              _aplicar(zoom: _zoom * fator, deslocamento: _deslocamento);
            }
          },
          child: GestureDetector(
            onScaleStart: (detalhes) {
              _zoomNoInicio = _zoom;
              _deslocamentoNoInicio = _deslocamento;
              _dedoNoInicio = detalhes.focalPoint;
            },
            onScaleUpdate: (detalhes) => _aplicar(
              zoom: _zoomNoInicio * detalhes.scale,
              deslocamento: _deslocamentoNoInicio +
                  (detalhes.focalPoint - _dedoNoInicio),
            ),
            child: ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Foto ampliada, centralizada e arrastada.
                  OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Transform.translate(
                      offset: _deslocamento,
                      child: SizedBox(
                        width: imagem.width * escala,
                        height: imagem.height * escala,
                        child: RawImage(image: imagem, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                  // Escurece fora do círculo e desenha a borda.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _Mascara(_diametro)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controles() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          const Text(
            'Arraste e aproxime para encaixar no círculo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _fonte, color: Colors.white70),
          ),
          Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: _zoom,
                  min: 1,
                  max: _zoomMaximo,
                  activeColor: AppColors.ciano,
                  label: 'Zoom',
                  onChanged: (valor) =>
                      _aplicar(zoom: valor, deslocamento: _deslocamento),
                ),
              ),
              const Icon(Icons.zoom_in, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _recortando ? null : _usar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ciano,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: _recortando
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Usar foto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Camada escura com um "furo" redondo no meio e a borda do círculo.
class _Mascara extends CustomPainter {
  final double diametro;

  _Mascara(this.diametro);

  @override
  void paint(Canvas canvas, Size size) {
    final circulo = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: diametro,
      height: diametro,
    );
    final fora = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(circulo);
    canvas.drawPath(fora, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawOval(
      circulo,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Mascara antiga) => antiga.diametro != diametro;
}
