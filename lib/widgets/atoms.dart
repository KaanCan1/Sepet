import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'glass.dart';
import 'motion.dart';

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
  const Hairline({super.key, this.color});

  /// Verilmezse temanın çizgi rengi.
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: color ?? context.c.line);
}

/// .delta — "Geçen aya göre 1,4 puan" rozeti.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.text, this.up = true});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? context.c.hot : context.c.ref;
    return Container(
      decoration: BoxDecoration(
        color: up ? context.c.hotBg : context.c.refBg,
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
            style: TextStyle(fontSize: 11.5, color: context.c.muted),
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
    this.amountColor,
  });

  final String name;
  final String? sub;
  final String amount;

  /// Verilmezse mürekkep rengi.
  final Color? amountColor;

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
              Text(name, style: TextStyle(fontSize: 12, color: context.c.ink)),
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
          style: T.num11.copyWith(
            fontSize: 11.5,
            color: amountColor ?? context.c.ink,
          ),
        ),
      ],
    ),
  );
}

/// Serif başlık + üst simge sayı ("47,2%").
class BigNumber extends StatelessWidget {
  const BigNumber(this.value, {super.key, this.size = 52, this.color});
  final String value;
  final double size;

  /// Verilmezse mürekkep rengi.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.c.ink;
    return Text.rich(
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
                  color: ink,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
      style: T.bigNumber.copyWith(fontSize: size, color: ink),
    );
  }
}

/// Fişin koparma çizgisi. Aylık kartın alt kenarında ve karşılama ekranının
/// kelime işaretinin iki yanında kullanılıyor.
class TearEdge extends StatelessWidget {
  const TearEdge({super.key, this.height = 9});

  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, height),
    painter: _TearPainter(context.c.ink),
  );
}

class _TearPainter extends CustomPainter {
  _TearPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color.withValues(alpha: .18);
    for (var x = 0.0; x < s.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, s.height), p);
    }
  }

  @override
  bool shouldRepaint(_TearPainter old) => old.color != color;
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
        color: known ? context.c.refBg : null,
        borderRadius: BorderRadius.circular(size * .23),
        border: known ? null : Border.all(color: context.c.line),
      ),
      child: Text(
        known ? text : '?',
        style: TextStyle(
          fontFamily: F.mono,
          fontFamilyFallback: F.monoFallback,
          fontSize: size * .36,
          fontWeight: FontWeight.w600,
          height: 1,
          color: known ? context.c.ref : context.c.grey,
        ),
      ),
    );
  }
}

/// Ekranın büyük başlığı. Üst bar yerine geçiyor: cam bar içeriği
/// bulanıklaştırıp yer kaplıyordu, oysa başlık kaydırılıp gidebilir.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {super.key, this.trailing, this.onBack});

  final String title;

  /// Sağdaki küçük mono etiket — ay, adet gibi.
  final String? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24, top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (onBack != null)
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 4, top: 2),
              child: Text(
                '‹',
                style: TextStyle(fontSize: 21, color: context.c.muted),
              ),
            ),
          ),
        Expanded(
          child: Text(
            title,
            style: T.largeTitle.copyWith(color: context.c.ink),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: T.label.copyWith(
              fontSize: 9.5,
              letterSpacing: 1.5,
              color: context.c.faint,
            ),
          ),
      ],
    ),
  );
}

/// Sıralı satır: ad solda, yüzde sağda, altında ince bar.
///
/// Kutu yok — ayırma işini alt çizgi yapıyor. Bar oranı gösteriyor ve
/// rengini kategoriden alıyor; sayı da aynı renkte, çünkü ikisi aynı şeyi
/// söylüyor.
class StatRow extends StatefulWidget {
  const StatRow({
    super.key,
    required this.name,
    required this.value,
    required this.ratio,
    required this.color,
    this.sub,
    this.onTap,
    this.step = 0,
  });

  final String name;
  final String value;

  /// 0..1 — bar dolgusu.
  final double ratio;
  final Color color;
  final String? sub;
  final VoidCallback? onTap;

  /// Kademeli girişte sıra.
  final int step;

  @override
  State<StatRow> createState() => _StatRowState();
}

class _StatRowState extends State<StatRow> {
  double _w = 0;

  @override
  void initState() {
    super.initState();
    // Bar soldan doluyor: oran zaten soldan sağa okunuyor.
    Future.delayed(M.stagger * (widget.step.clamp(0, M.maxStep) + 2), () {
      if (mounted) setState(() => _w = widget.ratio);
    });
  }

  @override
  void didUpdateWidget(StatRow old) {
    super.didUpdateWidget(old);
    if (old.ratio != widget.ratio) setState(() => _w = widget.ratio);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: widget.onTap,
      scale: 1,
      child: Container(
        padding: const EdgeInsets.only(top: 13, bottom: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: T.rowName.copyWith(color: c.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.value,
                  style: T.value.copyWith(color: widget.color),
                ),
              ],
            ),
            if (widget.sub != null) ...[
              const SizedBox(height: 3),
              Text(
                widget.sub!,
                style: T.label.copyWith(fontSize: 8.5, color: c.faint),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(height: 3, color: c.track),
                  AnimatedFractionallySizedBox(
                    duration: M.off(context) ? Duration.zero : M.draw,
                    curve: M.curve,
                    widthFactor: _w.clamp(0, 1),
                    alignment: Alignment.centerLeft,
                    child: Container(height: 3, color: widget.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Düz eylem satırı: solda ne olduğu, sağda küçük mono ipucu.
///
/// Chevron yok — ipucu zaten "burada ne var" diyor ve bir ayarlar
/// menüsünden ayırıyor.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.label, this.hint, this.onTap});

  final String label;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      scale: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: T.rowName.copyWith(color: c.ink)),
            ),
            if (hint != null)
              Text(hint!, style: T.label.copyWith(fontSize: 9, color: c.faint)),
          ],
        ),
      ),
    );
  }
}

/// Manşetin altındaki karşılaştırma satırı: resmî ölçüm ve aradaki fark.
///
/// Kontrol değil, okuma. Segment kaldırıldı — manşet her zaman senin sayın,
/// TÜİK burada ve grafikte kesikli çizgide duruyor.
class CompareRow extends StatelessWidget {
  const CompareRow({
    super.key,
    required this.label,
    required this.value,
    this.difference,
  });

  final String label;
  final String value;
  final String? difference;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Kesikli tire: grafikteki çizginin aynısı, lejant gerekmiyor.
          CustomPaint(size: const Size(13, 2), painter: _Dashes(c.ref)),
          const SizedBox(width: 6),
          Text(label, style: T.body.copyWith(fontSize: 11.5, color: c.muted)),
          const SizedBox(width: 9),
          Text(value, style: T.value.copyWith(fontSize: 13, color: c.ref)),
          const Spacer(),
          if (difference != null)
            Text(
              difference!,
              style: T.label.copyWith(fontSize: 10, color: c.faint),
            ),
        ],
      ),
    );
  }
}

class _Dashes extends CustomPainter {
  _Dashes(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < s.width; x += 5) {
      canvas.drawLine(Offset(x, 1), Offset((x + 3).clamp(0, s.width), 1), p);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}
