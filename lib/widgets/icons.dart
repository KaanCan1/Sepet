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
  apple,
  google,
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
    // Marka işaretleri kendi çizim kutularında tanımlı (Apple 814x1000,
    // Google 48x48) ve resmî yolların birebir aktarımı. Ortak 24'lük ölçekten
    // muaflar; ikisi de aynı yuvaya, aynı optik ağırlıkta oturtuluyor.
    if (glyph == Glyph.apple) {
      _brand(canvas, size, 814, 1000, .92, (c) {
        c.drawPath(_applePath(), Paint()..color = color);
      });
      return;
    }
    if (glyph == Glyph.google) {
      _brand(canvas, size, 48, 48, 1, _googleG);
      return;
    }

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
      case Glyph.apple:
      case Glyph.google:
        return; // yukarıda ele alındı
      case Glyph.check:
        path
          ..moveTo(5, 12.5)
          ..lineTo(10, 17.5)
          ..lineTo(19, 6.5);
    }
    canvas.drawPath(path, p);
  }

  /// Bir marka yolunu kendi kutusundan ikon yuvasına oturtur: oranı korur,
  /// ortalar, [factor] ile optik ağırlığı dengeler.
  void _brand(
    Canvas canvas,
    Size box,
    double vbWidth,
    double vbHeight,
    double factor,
    void Function(Canvas) draw,
  ) {
    final scale =
        (box.width / vbWidth < box.height / vbHeight
            ? box.width / vbWidth
            : box.height / vbHeight) *
        factor;
    canvas.save();
    canvas.translate(
      (box.width - vbWidth * scale) / 2,
      (box.height - vbHeight * scale) / 2,
    );
    canvas.scale(scale);
    draw(canvas);
    canvas.restore();
  }

  /// Apple logosu — resmî varlığın (814x1000) aktarımı. Gövde ve yaprak.
  Path _applePath() {
    final body = Path()
      ..moveTo(788.1, 340.9)
      ..relativeCubicTo(-5.8, 4.5, -108.2, 62.2, -108.2, 190.5)
      ..relativeCubicTo(0, 148.4, 130.3, 200.9, 134.2, 202.2)
      ..relativeCubicTo(-.6, 3.2, -20.7, 71.9, -68.7, 141.9)
      ..relativeCubicTo(-42.8, 61.6, -87.5, 123.1, -155.5, 123.1)
      // "s" kısayolları: önceki kontrol noktasının yansıması açıkça yazıldı.
      ..relativeCubicTo(-68, 0, -85.5, -39.5, -164, -39.5)
      ..relativeCubicTo(-76.5, 0, -103.7, 40.8, -165.9, 40.8)
      ..relativeCubicTo(-62.2, 0, -105.6, -57, -155.5, -127)
      ..cubicTo(46.7, 790.7, 0, 663, 0, 541.8)
      ..relativeCubicTo(0, -194.4, 126.4, -297.5, 250.8, -297.5)
      ..relativeCubicTo(66.1, 0, 121.2, 43.4, 162.7, 43.4)
      ..relativeCubicTo(39.5, 0, 101.1, -46, 176.3, -46)
      ..relativeCubicTo(28.5, 0, 130.9, 2.6, 198.3, 99.2)
      ..close();

    final leaf = Path()
      ..moveTo(554.1, 159.4)
      ..relativeCubicTo(31.1, -36.9, 53.1, -88.1, 53.1, -139.3)
      ..relativeCubicTo(0, -7.1, -.6, -14.3, -1.9, -20.1)
      ..relativeCubicTo(-50.6, 1.9, -110.8, 33.7, -147.1, 75.8)
      ..relativeCubicTo(-28.5, 32.4, -55.1, 83.6, -55.1, 135.5)
      ..relativeCubicTo(0, 7.8, 1.3, 15.6, 1.9, 18.1)
      ..relativeCubicTo(3.2, .6, 8.4, 1.3, 13.6, 1.3)
      ..relativeCubicTo(45.4, 0, 102.5, -30.4, 135.5, -71.3)
      ..close();

    return Path.combine(PathOperation.union, body, leaf);
  }

  /// Google "G" — resmî dört parçalı yol (48x48). Yay yaklaşımı tutmadı:
  /// gerçek işaret çizgi değil dolu yol, renk sınırları keskin.
  void _googleG(Canvas canvas) {
    final blue = Path()
      ..moveTo(45.12, 24.5)
      ..relativeCubicTo(0, -1.56, -.14, -3.06, -.4, -4.5)
      ..lineTo(24, 20)
      ..relativeLineTo(0, 8.51)
      ..relativeLineTo(11.84, 0)
      ..relativeCubicTo(-.51, 2.75, -2.06, 5.08, -4.39, 6.64)
      ..relativeLineTo(0, 5.52)
      ..relativeLineTo(7.11, 0)
      ..relativeCubicTo(4.16, -3.83, 6.56, -9.47, 6.56, -16.17)
      ..close();

    final green = Path()
      ..moveTo(24, 46)
      ..relativeCubicTo(5.94, 0, 10.92, -1.97, 14.56, -5.33)
      ..relativeLineTo(-7.11, -5.52)
      ..relativeCubicTo(-1.97, 1.32, -4.49, 2.1, -7.45, 2.1)
      ..relativeCubicTo(-5.73, 0, -10.58, -3.87, -12.31, -9.07)
      ..lineTo(4.34, 28.18)
      ..relativeLineTo(0, 5.7)
      ..cubicTo(7.96, 41.07, 15.4, 46, 24, 46)
      ..close();

    final yellow = Path()
      ..moveTo(11.69, 28.18)
      ..cubicTo(11.25, 26.86, 11, 25.45, 11, 24)
      ..cubicTo(11, 22.55, 11.25, 21.14, 11.69, 19.82)
      ..relativeLineTo(0, -5.7)
      ..lineTo(4.34, 14.12)
      ..cubicTo(2.85, 17.09, 2, 20.45, 2, 24)
      ..cubicTo(2, 27.55, 2.85, 30.91, 4.34, 33.88)
      ..relativeLineTo(7.35, -5.7)
      ..close();

    final red = Path()
      ..moveTo(24, 10.75)
      ..relativeCubicTo(3.23, 0, 6.13, 1.11, 8.41, 3.29)
      ..relativeLineTo(6.31, -6.31)
      ..cubicTo(34.91, 4.18, 29.93, 2, 24, 2)
      ..cubicTo(15.4, 2, 7.96, 6.93, 4.34, 14.12)
      ..relativeLineTo(7.35, 5.7)
      ..relativeCubicTo(1.73, -5.2, 6.58, -9.07, 12.31, -9.07)
      ..close();

    canvas.drawPath(blue, Paint()..color = const Color(0xFF4285F4));
    canvas.drawPath(green, Paint()..color = const Color(0xFF34A853));
    canvas.drawPath(yellow, Paint()..color = const Color(0xFFFBBC05));
    canvas.drawPath(red, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}
