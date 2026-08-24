import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Küçük mono etiket. Metin ZATEN büyük harfle yazılır — Dart'ın
/// `toUpperCase()`'i Türkçe'de i → I yapıp noktayı düşürüyor.
class Lbl extends StatelessWidget {
  const Lbl(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: color == null ? T.label : T.label.copyWith(color: color),
  );
}

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color = C.line});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

/// .delta — "Geçen aya göre 1,4 puan" rozeti.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.text, this.up = true});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? C.hot : C.ref;
    return Container(
      decoration: BoxDecoration(
        color: up ? C.hotBg : C.refBg,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.fromLTRB(8, 3.5, 9, 4.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size(8, 8), painter: _Arrow(color, up)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: F.mono,
              fontFamilyFallback: F.monoFallback,
              fontSize: 10,
              height: 1,
              letterSpacing: .4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends CustomPainter {
  _Arrow(this.color, this.up);
  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (up) {
      path
        ..moveTo(s.width / 2, s.height * .85)
        ..lineTo(s.width / 2, s.height * .15)
        ..moveTo(s.width * .18, s.height * .48)
        ..lineTo(s.width / 2, s.height * .15)
        ..lineTo(s.width * .82, s.height * .48);
    } else {
      path
        ..moveTo(s.width / 2, s.height * .15)
        ..lineTo(s.width / 2, s.height * .85)
        ..moveTo(s.width * .18, s.height * .52)
        ..lineTo(s.width / 2, s.height * .85)
        ..lineTo(s.width * .82, s.height * .52);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Arrow old) => old.color != color || old.up != up;
}

/// .row — nokta + ad + monospace değer.
class SeriesRow extends StatelessWidget {
  const SeriesRow({
    super.key,
    required this.color,
    required this.name,
    required this.value,
  });

  final Color color;
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
        ),
        Text(value, style: T.num12),
      ],
    ),
  );
}

/// .r — sol tarafta ad + alt satır, sağda monospace tutar.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.name,
    this.sub,
    required this.amount,
    this.amountColor = C.ink,
  });

  final String name;
  final String? sub;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, color: C.ink)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub!, style: T.label),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          amount,
          style: T.num11.copyWith(fontSize: 11.5, color: amountColor),
        ),
      ],
    ),
  );
}

/// Serif başlık + üst simge sayı ("47,2%").
class BigNumber extends StatelessWidget {
  const BigNumber(this.value, {super.key, this.size = 60, this.color = C.ink});
  final String value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: value),
        // vertical-align: super — TextStyle'da baseline kaydırma yok,
        // WidgetSpan'ı metnin tepesine hizalıyoruz.
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Padding(
            padding: EdgeInsets.only(top: size * .15),
            child: Text(
              '%',
              style: T.bigNumber.copyWith(
                fontSize: size * .43,
                color: color,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    ),
    style: T.bigNumber.copyWith(fontSize: size, color: color),
  );
}

/// Fişin koparma çizgisi. Aylık kartın alt kenarında ve karşılama ekranının
/// kelime işaretinin iki yanında kullanılıyor.
class TearEdge extends StatelessWidget {
  const TearEdge({super.key, this.height = 9});

  final double height;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(double.infinity, height), painter: _TearPainter());
}

class _TearPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = C.ink.withValues(alpha: .18);
    for (var x = 0.0; x < s.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, s.height), p);
    }
  }

  @override
  bool shouldRepaint(_TearPainter old) => false;
}

/// Marka rozeti — logo değil, baş harfler.
///
/// Logo servisleri alan adı tabanlı çalışıyor ve telefondan çağrılırsa
/// kullanıcının sepetini üçüncü tarafa sızdırır; bu uygulamanın tüm mimarisi
/// fişin cihazdan çıkmaması üzerine kurulu. Küçük üreticilerde (Hasata,
/// Untad, Viva) zaten kapsama da yok.
///
/// Renk referans mavisi: zam kırmızısı yalnızca dikkat isteyen satırlarda
/// kalsın diye — tek renk vurgusu bölünmüyor.
class BrandChip extends StatelessWidget {
  const BrandChip(this.text, {super.key, this.known = true, this.size = 22});

  final String text;

  /// Eşleşme yoksa kesik çerçeveli soru işareti.
  final bool known;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: known ? C.refBg : null,
        borderRadius: BorderRadius.circular(size * .23),
        border: known ? null : Border.all(color: C.line),
      ),
      child: Text(
        known ? text : '?',
        style: TextStyle(
          fontFamily: F.mono,
          fontFamilyFallback: F.monoFallback,
          fontSize: size * .36,
          fontWeight: FontWeight.w600,
          height: 1,
          color: known ? C.ref : C.grey,
        ),
      ),
    );
  }
}
