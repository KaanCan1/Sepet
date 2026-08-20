import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Taslaktaki SVG glyph'lerin birebir karşılığı — hepsi 24x24 kutuda,
/// dolgu yok, 1.5–1.6 kalınlıkta çizgi.
enum Glyph {
  home,
  doc,
  chart,
  clock,
  close,
  back,
  kebab,
  camera,
  check,
  chevron,
  person,
}

class LineIcon extends StatelessWidget {
  const LineIcon(
    this.glyph, {
    super.key,
    this.size = 17,
    this.color = C.ink,
    this.stroke = 1.5,
  });

  final Glyph glyph;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _GlyphPainter(glyph, color, stroke)),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color, this.stroke);

  final Glyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke / k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();

    switch (glyph) {
      case Glyph.home:
        path
          ..moveTo(4, 19)
          ..lineTo(4, 9)
          ..lineTo(12, 4)
          ..lineTo(20, 9)
          ..lineTo(20, 19)
          ..moveTo(4, 19)
          ..lineTo(20, 19);
      case Glyph.doc:
        path
          ..addRRect(RRect.fromLTRBR(4, 3, 20, 21, const Radius.circular(2)))
          ..moveTo(8, 8)
          ..lineTo(16, 8)
          ..moveTo(8, 12)
          ..lineTo(16, 12)
          ..moveTo(8, 16)
          ..lineTo(13, 16);
      case Glyph.chart:
        path
          ..moveTo(4, 18)
          ..lineTo(9, 12)
          ..lineTo(13, 16)
          ..lineTo(20, 7);
      case Glyph.clock:
        canvas.drawCircle(const Offset(12, 12), 9, p);
        path
          ..moveTo(12, 8)
          ..lineTo(12, 12)
          ..lineTo(15, 14);
      case Glyph.close:
        path
          ..moveTo(6, 6)
          ..lineTo(18, 18)
          ..moveTo(18, 6)
          ..lineTo(6, 18);
      case Glyph.back:
        path
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
      case Glyph.chevron:
        path
          ..moveTo(9, 5)
          ..lineTo(16, 12)
          ..lineTo(9, 19);
      case Glyph.kebab:
        for (final y in [5.0, 12.0, 19.0]) {
          canvas.drawCircle(Offset(12, y), 1.4, Paint()..color = color);
        }
      case Glyph.camera:
        path
          ..moveTo(3, 8)
          ..lineTo(3, 19)
          ..lineTo(21, 19)
          ..lineTo(21, 8)
          ..lineTo(16.5, 8)
          ..lineTo(15, 5)
          ..lineTo(9, 5)
          ..lineTo(7.5, 8)
          ..close();
        canvas.drawCircle(const Offset(12, 13), 3.6, p);
      case Glyph.person:
        canvas.drawCircle(const Offset(12, 8.5), 3.9, p);
        path
          ..moveTo(4.6, 20)
          ..cubicTo(5.4, 16.2, 8.4, 14.4, 12, 14.4)
          ..cubicTo(15.6, 14.4, 18.6, 16.2, 19.4, 20);
      case Glyph.check:
        path
          ..moveTo(5, 12.5)
          ..lineTo(10, 17.5)
          ..lineTo(19, 6.5);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}
