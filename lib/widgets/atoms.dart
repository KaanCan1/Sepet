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

/// .flag — normalizasyonun emin olamadığı satırın işareti.
class MatchFlag extends StatelessWidget {
  const MatchFlag({super.key, this.text = 'eşleşme?'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.fromLTRB(5, 2, 5, 2.5),
    decoration: BoxDecoration(
      color: C.refBg,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: F.mono,
        fontFamilyFallback: F.monoFallback,
        fontSize: 8.5,
        height: 1,
        color: C.ref,
      ),
    ),
  );
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
