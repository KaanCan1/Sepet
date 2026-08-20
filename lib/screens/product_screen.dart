import 'package:flutter/cupertino.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// 03 — Ürün geçmişi. Endeksin altındaki tek tek gözlemler; sayının nereden
/// geldiğini burada görüyorsun.
class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, required this.product});

  final Product product;

  static Route<void> route(Product p) =>
      CupertinoPageRoute(builder: (_) => ProductScreen(product: p));

  @override
  Widget build(BuildContext context) {
    final prices = product.history.map((e) => e.price).toList();
    final janIndex = product.history.indexWhere((e) => e.date.month == 1);
    // Ucuzdan pahalıya; barlar fiyat aralığına göre ölçekleniyor, sıfıra göre
    // değil — yoksa yakın fiyatlar ayırt edilemeyen dolu barlara dönüşüyor.
    final markets = List<MarketPrice>.of(product.byMarket)
      ..sort((a, b) => a.price.compareTo(b.price));
    final hi = markets.last.price;
    final floor = markets.first.price * .8;

    return ScreenFrame(
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.back, size: 17, color: C.ink, stroke: 1.6),
        ),
      ),
      trailing: const Padding(
        padding: EdgeInsets.all(4),
        child: LineIcon(Glyph.kebab, size: 17, color: C.muted),
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 4),
              const Lbl('SEPETİNDEKİ ÜRÜN'),
              const SizedBox(height: 4),
              Text(product.title, style: T.display),
              const SizedBox(height: 4),
              Text(
                '${product.observations} GÖZLEM · '
                '${product.marketCount} MARKET · ${product.monthSpan} AY',
                style: T.label.copyWith(fontSize: 10, letterSpacing: .6),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat('İLK GÖRDÜĞÜN', Fmt.money(product.first)),
                  const SizedBox(width: 22),
                  _Stat('ŞİMDİ', Fmt.money(product.last)),
                  const SizedBox(width: 22),
                  _Stat(
                    'DEĞİŞİM',
                    Fmt.signedPct0(product.changePct),
                    color: product.changePct >= 0 ? C.hot : C.ref,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LineChart(
                height: 110,
                series: [
                  ChartSeries(values: prices, color: C.ink, endDot: true),
                ],
                marker: janIndex >= 0 ? janIndex : null,
                markerLabel: janIndex >= 0
                    ? Fmt.monthShort(product.history[janIndex].date)
                    : null,
              ),
              const SizedBox(height: 14),
              const Hairline(),
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 4),
                child: Lbl('EN SON GÖRDÜĞÜN FİYATLAR'),
              ),
              for (final m in markets)
                _MarketRow(
                  entry: m,
                  fraction: (m.price - floor) / (hi - floor),
                  cheapest: m == markets.first,
                ),
              const SizedBox(height: 14),
              Text(
                'Bu ürün endekste ${product.observations} gözlemle temsil '
                'ediliyor. Ağırlığı, senin harcamandaki payına göre.',
                style:
                    const TextStyle(fontSize: 11, height: 1.5, color: C.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color = C.ink});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Lbl(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: F.mono,
              fontFamilyFallback: F.monoFallback,
              fontSize: 17,
              color: color,
            ),
          ),
        ],
      );
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.entry,
    required this.fraction,
    this.cheapest = false,
  });
  final MarketPrice entry;
  final double fraction;
  final bool cheapest;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    entry.market,
                    style: const TextStyle(fontSize: 11.5, color: C.ink),
                  ),
                  if (cheapest) ...[
                    const SizedBox(width: 6),
                    Text('EN UCUZ', style: T.label.copyWith(fontSize: 8.5)),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 74,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(height: 5, color: C.line),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(.08, 1),
                      child: Container(
                        height: 5,
                        color: cheapest ? C.ref : C.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                Fmt.money(entry.price),
                textAlign: TextAlign.right,
                style: T.num11,
              ),
            ),
          ],
        ),
      );
}
