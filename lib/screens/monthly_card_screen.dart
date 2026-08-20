import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'product_screen.dart';

/// 04 — Aylık kart. Pazarlama motoru: ayın 3'ünde TÜİK verisi çıkınca gelen
/// bildirimin varış noktası. Kartın kenarı fişin koparma çizgisi.
class MonthlyCardScreen extends StatefulWidget {
  const MonthlyCardScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MonthlyCardScreen(),
      );

  @override
  State<MonthlyCardScreen> createState() => _MonthlyCardScreenState();
}

class _MonthlyCardScreenState extends State<MonthlyCardScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sepet-${Mock.now.month}.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${Fmt.monthLong(Mock.now)} ayında benim sepetim '
              '${Fmt.pct1(Mock.headline)} zamlandı. Kendi fişimden hesapladım.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final bytes = await _capture();
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sepet-${Mock.now.month}.png');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            'Görsel kaydedildi · ${(bytes.length / 1024).round()} KB',
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final month = Fmt.monthLong(Mock.now);

    return ScreenFrame(
      title: '$month özeti',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.close, size: 17, color: C.muted, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 6),
              RepaintBoundary(
                key: _cardKey,
                child: _ShareCard(month: month),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Görseli kaydet',
                      dark: false,
                      onTap: _save,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label: _busy ? 'Hazırlanıyor…' : 'Paylaş',
                      onTap: _busy ? null : _share,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Hairline(),
              const SizedBox(height: 12),
              const Lbl('BU AY EN ÇOK ZAMLANAN'),
              const SizedBox(height: 2),
              for (final m in Mock.movers)
                Pressable(
                  onTap: () {
                    final p = Mock.products.firstWhere(
                      (p) => m.name.startsWith(p.name),
                      orElse: () => Mock.oil,
                    );
                    Navigator.of(context).push(ProductScreen.route(p));
                  },
                  child: LedgerRow(
                    name: m.name,
                    amount: Fmt.signedPct1(m.pct),
                    amountColor: m.pct >= 0 ? C.hot : C.ref,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    final tuik = Mock.series[1];
    final enag = Mock.series[2];

    return PaperCard(
      radius: 12,
      borderColor: C.ink,
      borderWidth: 1,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$month ${Mock.now.year} · 12 AYLIK',
            style: T.label.copyWith(fontSize: 9, letterSpacing: 1.26),
          ),
          const SizedBox(height: 10),
          BigNumber(Fmt.dec1(Mock.headline), size: 52),
          const SizedBox(height: 2),
          const Lbl('BENİM SEPETİM'),
          const SizedBox(height: 8),
          Text(
            '${Mock.receiptCount} fiş, ${Mock.observationCount} ürün gözlemi '
            'üzerinden hesaplandı. Aynı dönemde ${tuik.name.split(' ').first} '
            '${Fmt.pct1(tuik.value)}, ${enag.name.split(' ').first} '
            '${Fmt.pct1(enag.value)} açıkladı.',
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: C.muted),
          ),
          const SizedBox(height: 14),
          const _TearEdge(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SEPET', style: T.label.copyWith(fontSize: 8.5)),
              Text('KENDİ FİŞİNDEN', style: T.label.copyWith(fontSize: 8.5)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fişin koparma çizgisi.
class _TearEdge extends StatelessWidget {
  const _TearEdge();

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(double.infinity, 9), painter: _TearPainter());
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
  bool shouldRepaint(_) => false;
}
