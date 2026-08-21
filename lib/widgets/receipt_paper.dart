import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';

/// Fişi kâğıt hâliyle çizer: yırtık üst ve alt kenar, termal yazıcı
/// tipografisi, hafif buruşukluk.
///
/// Uygulamanın malzemesi kâğıt fiş; veriyi tabloya çevirmeden önce bir kez de
/// geldiği gibi göstermek, ekranın ne hakkında olduğunu tek bakışta anlatıyor.
class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({super.key, required this.receipt, this.width = 268});

  final Receipt receipt;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        // Elle bırakılmış gibi dursun — tam dik durursa şablon gibi görünüyor.
        angle: -0.012,
        child: SizedBox(
          width: width,
          child: Stack(
            children: [
              // Gölge yırtık kenarın şeklini almalı, dikdörtgenin değil.
              Positioned.fill(
                child: CustomPaint(painter: const _ShadowPainter()),
              ),
              ClipPath(
                clipper: _TornPaperClipper(),
                child: ColoredBox(
                  color: const Color(0xFFFCFBF8),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
                        child: _Content(receipt: receipt),
                      ),
                      // Buruşukluk içeriğin üstünde: kâğıdın kendisi kırışık,
                      // mürekkep onun üstünde duruyor.
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _CreasePainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.receipt});

  final Receipt receipt;

  static const _ink = Color(0xFF4A4844);
  static const _faint = Color(0xFF8C8983);

  TextStyle get _base => const TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 9.5,
    height: 1.75,
    color: _ink,
  );

  /// Fiş numarası kimliğin ilk hanelerinden. Kimlik kısaysa olduğu gibi —
  /// substring(0, 6) kör bir varsayımdı ve kısa kimlikte patlıyordu.
  static String _receiptNo(String id) {
    final clean = id.replaceAll('-', '');
    return clean.substring(0, math.min(6, clean.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final d = receipt.date;
    final date =
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

    return DefaultTextStyle(
      style: _base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              receipt.merchant.toUpperCase(),
              style: _base.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
                color: const Color(0xFF33312E),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              'SATIŞ FİŞİ',
              style: _base.copyWith(
                fontSize: 8,
                letterSpacing: 2,
                color: _faint,
              ),
            ),
          ),
          const _Perforation(),
          _Row(left: 'TARİH', right: date),
          _Row(left: 'FİŞ NO', right: _receiptNo(receipt.id)),
          const _Perforation(),

          for (final line in receipt.lines) _Item(line: line, style: _base),

          const _Perforation(),
          _Row(left: 'TOPLAM', right: Fmt.money(receipt.total), bold: true),
          const _Perforation(),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'TEŞEKKÜR EDERİZ',
              style: _base.copyWith(
                fontSize: 8,
                letterSpacing: 2,
                color: _faint,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Barkod, fişin alt kenarındaki alışıldık bant.
          const _Barcode(),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.left, required this.right, this.bold = false});

  final String left;
  final String right;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final s = bold
        ? style.copyWith(fontWeight: FontWeight.w500, fontSize: 10.5)
        : style;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: s),
        Text(right, style: s),
      ],
    );
  }
}

/// Ürün satırı: adı üstte, çarpanlı ise adet × birim fiyat altta.
class _Item extends StatelessWidget {
  const _Item({required this.line, required this.style});

  final ReceiptLine line;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final multiple = line.quantity != 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (multiple) ...[
            Text(line.raw, style: style),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '  ${ReceiptLine.qtyLabel(line.quantity)} X '
                  '${Fmt.money(line.amount / line.quantity)}',
                  style: style.copyWith(color: _Content._faint),
                ),
                Text(Fmt.money(line.amount), style: style),
              ],
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    line.raw,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                const SizedBox(width: 8),
                Text(Fmt.money(line.amount), style: style),
              ],
            ),
        ],
      ),
    );
  }
}

/// Termal fişlerdeki kesikli ayraç.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(
      height: 1,
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashPainter(),
      ),
    ),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFFB9B5AD);
    for (var x = 0.0; x < s.width; x += 5) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 3, 1), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _Barcode extends StatelessWidget {
  const _Barcode();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 26,
    child: CustomPaint(
      size: const Size(double.infinity, 26),
      painter: _BarcodePainter(),
    ),
  );
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    // Sabit tohum: her karede farklı bir barkod çizmesin.
    final rnd = math.Random(7);
    final p = Paint()..color = const Color(0xFF4A4844);
    var x = 6.0;
    while (x < s.width - 6) {
      final w = rnd.nextBool() ? 1.0 : 2.0;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, s.height), p);
      x += w + (rnd.nextBool() ? 2.0 : 3.0);
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => false;
}

/// Üst ve alt kenarı yırtık kâğıt biçimi.
class _TornPaperClipper extends CustomClipper<Path> {
  static const tooth = 7.0;
  static const depth = 5.0;

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, depth);
    // Üst kenar: aşağı bakan dişler.
    var x = 0.0;
    var up = true;
    while (x < size.width) {
      x = math.min(x + tooth, size.width);
      path.lineTo(x, up ? 0 : depth);
      up = !up;
    }
    path.lineTo(size.width, size.height - depth);
    // Alt kenar: geri dönerken ters yönde.
    while (x > 0) {
      x = math.max(x - tooth, 0);
      path.lineTo(x, up ? size.height : size.height - depth);
      up = !up;
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TornPaperClipper old) => false;
}

/// Yırtık kenarın gölgesi.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final path = _TornPaperClipper().getClip(s);
    canvas.drawPath(
      path.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x2216181A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => false;
}

/// Buruşukluk: birkaç yumuşak çapraz bant ve bir dikey kat izi.
///
/// Doku görseli yerine gradyan kullanılıyor — varlık dosyası taşımadan,
/// her ölçekte net.
class _CreasePainter extends CustomPainter {
  const _CreasePainter();

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;

    // Çapraz kırışıklıklar: her biri açık bir tepe ve koyu bir vadi.
    const creases = <(double, double, double)>[
      // (yükseklik 0..1, açı, güç) — "hafif" buruşuk: bantlar geniş ve soluk,
      // dar ve parlak olursa ışık huzmesi gibi okunuyor.
      (0.20, -0.22, 0.030),
      (0.52, 0.16, 0.024),
      (0.79, -0.12, 0.028),
    ];

    for (final (at, angle, strength) in creases) {
      canvas.save();
      canvas.translate(s.width / 2, s.height * at);
      canvas.rotate(angle);
      final band = Rect.fromCenter(
        center: Offset.zero,
        width: s.width * 1.8,
        height: 46,
      );
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0x00000000),
              Color.fromRGBO(255, 255, 255, strength * 2.2),
              Color.fromRGBO(90, 84, 74, strength),
              const Color(0x00000000),
            ],
            stops: const [0, .40, .60, 1],
          ).createShader(band),
      );
      canvas.restore();
    }

    // Dikey kat izi: kâğıt bir kez ikiye katlanmış gibi.
    final fold = Rect.fromLTWH(s.width * 0.63, 0, 22, s.height);
    canvas.drawRect(
      fold,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0x00000000),
            Color(0x085A544A),
            Color(0x0CFFFFFF),
            Color(0x00000000),
          ],
          stops: [0, .45, .6, 1],
        ).createShader(fold),
    );

    // Kenarlara doğru çok hafif kararma — kâğıt düz bir yüzey değil.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: .95,
          colors: [Color(0x00000000), Color(0x0D5A544A)],
          stops: [.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CreasePainter old) => false;
}
