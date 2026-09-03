import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Serinin son noktasındaki işaret.
///
/// [dot] senin çizgin: dolu nokta "seri burada bitiyor" der.
/// [ring] referans çizgisi: içi boş halka "BİLİNEN son değer bu" der.
///
/// Ayrım süs değil. Resmî seri kullanıcınınkinden erken bitebiliyor — TÜİK
/// içinde bulunulan ayı henüz açıklamamış olur — ve işaretsiz kesilen bir
/// çizgi ekranda çizim hatası gibi okunuyordu: kesikli çizgi grafiğin
/// ortasında boşlukta duruyordu.
enum EndCap { none, dot, ring }

class ChartSeries {
  const ChartSeries({
    required this.values,
    required this.color,
    this.width = 1.8,
    this.dashed = false,
    this.end = EndCap.none,
    this.fill,
  });

  /// Boş bırakılabilir: null olan ay çizilmiyor, çizgi orada kesiliyor.
  ///
  /// Eksik bir ayı komşularına bağlamak "o ay da böyleydi" demek olurdu.
  /// Resmî seri kullanıcının son ayını henüz açıklamamış olabiliyor; çizgi
  /// orada bitiyor, uzatılmıyor.
  final List<double?> values;
  final Color color;
  final double width;
  final bool dashed;
  final EndCap end;

  /// Çizginin altını dolduran renk. Verilirse tepede bu renk, tabanda
  /// saydam bir geçiş çiziliyor — çizginin taşıdığı yönü zeminde de
  /// tekrarlıyor, ayrı bir bilgi eklemiyor.
  final Color? fill;
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
        painter: _LinePainter(
          series,
          marker,
          markerLabel,
          progress,
          guides,
          context.c,
        ),
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
    this.colors,
  );

  /// Boyacının context'i yok; ızgara ve işaret renkleri buradan geliyor.
  final SepetColors colors;

  final List<ChartSeries> series;
  final int? marker;
  final String? markerLabel;
  final double progress;
  final bool guides;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.line
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

    // Ölçek bütün serilerde ORTAK. Her seriyi kendi en küçük-en büyüğüne
    // yaymak iki farklı eğriyi üst üste bindirir ve "aynı seviyedeler" gibi
    // okutur; oysa yan yana konmalarının tek sebebi farkları.
    var lo = double.infinity, hi = -double.infinity;
    for (final s in series) {
      for (final v in s.values) {
        if (v == null) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (lo == double.infinity) return;
    if (hi - lo < 1e-9) hi = lo + 1;
    // Üstte ve altta nefes payı bırak — az, yoksa eğim düzleşiyor.
    final pad = (hi - lo) * .06;
    lo -= pad;
    hi += pad;

    const inset = 5.0;
    final top = 8.0;
    final bottom = size.height - 8;

    // x, serinin kendi uzunluğuna değil ORTAK zaman eksenine göre: iki seri
    // aynı ayda aynı yerde duruyor. Eskiden her seri tüm genişliğe kendi
    // nokta sayısıyla yayılıyordu; farklı uzunlukta iki seri zamanda kayardı.
    final span = series.fold<int>(
      0,
      (a, s) => s.values.length > a ? s.values.length : a,
    );

    Offset at(List<double?> v, int i) {
      final x = span == 1
          ? size.width / 2
          : inset + (size.width - inset * 2) * (i / (span - 1));
      final t = (v[i]! - lo) / (hi - lo);
      return Offset(x, bottom - (bottom - top) * t);
    }

    for (final s in series) {
      final pts = [
        for (var i = 0; i < s.values.length; i++)
          s.values[i] == null ? null : at(s.values, i),
      ];
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (final drawn in _runs(pts, progress, span)) {
        if (s.fill != null) {
          final base = size.height;
          final area = Path()..moveTo(drawn.first.dx, base);
          for (final p in drawn) {
            area.lineTo(p.dx, p.dy);
          }
          area
            ..lineTo(drawn.last.dx, base)
            ..close();
          canvas.drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [s.fill!, s.fill!.withValues(alpha: 0)],
              ).createShader(Rect.fromLTWH(0, top, size.width, base - top)),
          );
        }

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
      }

      if (s.end != EndCap.none && progress > .98) {
        final son = pts.lastWhere((p) => p != null, orElse: () => null);
        if (son != null) {
          switch (s.end) {
            case EndCap.none:
              break;
            case EndCap.dot:
              canvas.drawCircle(son, 2.8, Paint()..color = s.color);
            case EndCap.ring:
              // İçi zeminle doldurulup üstü çiziliyor: altından geçen alan
              // dolgusu halkanın içini kirletmesin.
              canvas.drawCircle(son, 2.6, Paint()..color = colors.card);
              canvas.drawCircle(
                son,
                2.6,
                Paint()
                  ..color = s.color
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4,
              );
          }
        }
      }
    }

    if (marker != null && series.isNotEmpty && progress > .98) {
      final v = series.first.values;
      if (marker! >= 0 && marker! < v.length && v[marker!] != null) {
        final p = at(v, marker!);
        canvas.drawCircle(p, 2.4, Paint()..color = colors.card);
        canvas.drawCircle(
          p,
          2.4,
          Paint()
            ..color = colors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        if (markerLabel != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: markerLabel,
              style: TextStyle(
                fontFamily: F.mono,
                fontFamilyFallback: F.monoFallback,
                fontSize: 7,
                color: colors.muted,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(p.dx - tp.width - 4, p.dy - tp.height - 2));
        }
      }
    }
  }

  /// Çizim animasyonu için kesintisiz parçalar.
  ///
  /// Boşluklu bir seri tek bir yol değil: eksik ay, çizginin oradan geçtiği
  /// anlamına gelmez. Her kesintisiz koşu ayrı çiziliyor.
  ///
  /// İlerleme ORTAK zaman ekseni ([span]) üzerinden ölçülüyor, serinin kendi
  /// uzunluğundan değil — iki çizgi aynı anda aynı aya varıyor.
  List<List<Offset>> _runs(List<Offset?> pts, double t, int span) {
    final cut = (span - 1) * t.clamp(0.0, 1.0);
    final out = <List<Offset>>[];
    var run = <Offset>[];

    void flush() {
      if (run.length >= 2) out.add(run);
      run = <Offset>[];
    }

    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      if (p == null) {
        flush();
        continue;
      }
      if (i <= cut) {
        run.add(p);
        continue;
      }
      // Sınır bu koşunun içine düştü: son parçayı tam orada kes.
      // run doluysa bir önceki nokta da dolu demektir (boşlukta boşaltılıyor).
      if (run.isNotEmpty) {
        run.add(Offset.lerp(pts[i - 1]!, p, cut - (i - 1))!);
      }
      break;
    }
    flush();
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
      old.colors != colors ||
      old.progress != progress ||
      old.series != series ||
      old.marker != marker ||
      old.guides != guides;
}

/// Çizgisi soldan sağa çizilen grafik.
///
/// [LineChart] bunu ilk günden `progress` ile destekliyordu, çalıştıran
/// yoktu. Hareketin sebebi süs değil: grafiğin yatay ekseni zaman, çizginin
/// soldan sağa ilerlemesi o ekseni okutuyor. Aynı sebeple ters yönde ya da
/// solarak girmiyor.
///
/// Bir kez oynuyor. Aşağı çekip tazelemek çizgiyi baştan çizdirmiyor —
/// tazeleme yeni bir zaman ekseni değil.
class DrawnLineChart extends StatefulWidget {
  const DrawnLineChart({
    super.key,
    required this.series,
    this.height = 74,
    this.marker,
    this.markerLabel,
    this.guides = true,
    this.delay = Duration.zero,
  });

  final List<ChartSeries> series;
  final double height;
  final int? marker;
  final String? markerLabel;
  final bool guides;

  /// Kademeli girişte sıranın kaçıncısıysa o kadar bekliyor: çizgi, üstündeki
  /// kart daha belirmeden çizilmeye başlamasın.
  final Duration delay;

  @override
  State<DrawnLineChart> createState() => _DrawnLineChartState();
}

class _DrawnLineChartState extends State<DrawnLineChart>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: M.draw);
  late final _t = CurvedAnimation(parent: _c, curve: M.curve);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (M.off(context)) {
      return LineChart(
        series: widget.series,
        height: widget.height,
        marker: widget.marker,
        markerLabel: widget.markerLabel,
        guides: widget.guides,
      );
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => LineChart(
        series: widget.series,
        height: widget.height,
        marker: widget.marker,
        markerLabel: widget.markerLabel,
        guides: widget.guides,
        progress: _t.value,
      ),
    );
  }
}
