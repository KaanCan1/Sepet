import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

class ChartSeries {
  const ChartSeries({
    required this.values,
    required this.color,
    this.width = 1.8,
    this.dashed = false,
    this.endDot = false,
  });

  final List<double> values;
  final Color color;
  final double width;
  final bool dashed;
  final bool endDot;
}

/// Taslaktaki iki grafiğin ortak motoru: alt taban çizgisi, kesikli orta çizgi,
/// üstünde bir veya birkaç seri. Dolgu yok — mürekkep sadece çizgide.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.series,
    this.height = 74,
    this.marker,
    this.markerLabel,
    this.progress = 1,
    this.guides = true,
  });

  final List<ChartSeries> series;
  final double height;

  /// İçi boş halka konacak nokta indeksi (ilk serideki).
  final int? marker;
  final String? markerLabel;

  /// 0..1 — çizgi çizim animasyonu.
  final double progress;

  /// Taban çizgisi ve kesikli orta çizgi. Satır içi kıvılcım boyutunda
  /// (26 px) bunlar çizgiden çok yer kaplayıp gürültü yapıyor; oralarda
  /// kapatılıyor.
  final bool guides;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(series, marker, markerLabel, progress, guides),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(
    this.series,
    this.marker,
    this.markerLabel,
    this.progress,
    this.guides,
  );

  final List<ChartSeries> series;
  final int? marker;
  final String? markerLabel;
  final double progress;
  final bool guides;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;

    if (guides) {
      final baseY = size.height - 1;
      canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), grid);
      _dash(
        canvas,
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        grid,
        on: 2,
        off: 3,
      );
    }

    var lo = double.infinity, hi = -double.infinity;
    for (final s in series) {
      for (final v in s.values) {
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (hi - lo < 1e-9) hi = lo + 1;
    // Üstte ve altta nefes payı bırak — az, yoksa eğim düzleşiyor.
    final pad = (hi - lo) * .06;
    lo -= pad;
    hi += pad;

    const inset = 5.0;
    final top = 8.0;
    final bottom = size.height - 8;

    Offset at(List<double> v, int i) {
      final x = v.length == 1
          ? size.width / 2
          : inset + (size.width - inset * 2) * (i / (v.length - 1));
      final t = (v[i] - lo) / (hi - lo);
      return Offset(x, bottom - (bottom - top) * t);
    }

    for (final s in series) {
      final pts = [for (var i = 0; i < s.values.length; i++) at(s.values, i)];
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final drawn = _trim(pts, progress);
      if (drawn.length < 2) continue;

      if (s.dashed) {
        for (var i = 0; i < drawn.length - 1; i++) {
          _dash(canvas, drawn[i], drawn[i + 1], paint, on: 3, off: 3);
        }
      } else {
        final path = Path()..moveTo(drawn.first.dx, drawn.first.dy);
        for (final p in drawn.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }

      if (s.endDot && progress > .98) {
        canvas.drawCircle(pts.last, 2.8, Paint()..color = s.color);
      }
    }

    if (marker != null && series.isNotEmpty && progress > .98) {
      final v = series.first.values;
      if (marker! >= 0 && marker! < v.length) {
        final p = at(v, marker!);
        canvas.drawCircle(p, 2.4, Paint()..color = C.card);
        canvas.drawCircle(
          p,
          2.4,
          Paint()
            ..color = C.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        if (markerLabel != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: markerLabel,
              style: const TextStyle(
                fontFamily: F.mono,
                fontFamilyFallback: F.monoFallback,
                fontSize: 7,
                color: C.muted,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(p.dx - tp.width - 4, p.dy - tp.height - 2));
        }
      }
    }
  }

  /// Çizim animasyonu için noktaları kısalt.
  List<Offset> _trim(List<Offset> pts, double t) {
    if (t >= 1 || pts.length < 2) return pts;
    final total = (pts.length - 1) * t;
    final full = total.floor();
    final out = pts.sublist(0, (full + 1).clamp(1, pts.length));
    final frac = total - full;
    if (frac > 0 && full + 1 < pts.length) {
      out.add(Offset.lerp(pts[full], pts[full + 1], frac)!);
    }
    return out;
  }

  void _dash(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    required double on,
    required double off,
  }) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = (d + on).clamp(0.0, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d = end + off;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress ||
      old.series != series ||
      old.marker != marker ||
      old.guides != guides;
}
