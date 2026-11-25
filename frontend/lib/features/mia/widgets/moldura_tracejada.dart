import 'package:flutter/material.dart';

/// Borda tracejada branca em volta da área onde a receita deve ficar.
class MolduraTracejada extends StatelessWidget {
  final Widget child;

  const MolduraTracejada({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _Tracejado(),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
      ),
    );
  }
}

class _Tracejado extends CustomPainter {
  static const _traco = 10.0;
  static const _espaco = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final borda = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(10),
        ),
      );
    final pincel = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final contorno in borda.computeMetrics()) {
      for (var d = 0.0; d < contorno.length; d += _traco + _espaco) {
        canvas.drawPath(contorno.extractPath(d, d + _traco), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
