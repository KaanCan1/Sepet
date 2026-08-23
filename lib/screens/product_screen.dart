import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../state/products_cubit.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// 03 — Ürün geçmişi. Endeksin altındaki tek tek gözlemler; sayının nereden
/// geldiğini burada görüyorsun.
class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  /// Ayrıntı cubit'i yönlendirmeyle birlikte doğup ölüyor: ekrandan
  /// çıkıldığında durum da gitmeli, bir sonraki ürün eskisinin verisiyle
  /// açılmamalı.
  static Route<void> route(String id) => CupertinoPageRoute(
    builder: (context) => BlocProvider(
      create: (_) => ProductDetailCubit(context.read<Repository>(), id)..load(),
      child: ProductScreen(productId: id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.back, size: 17, color: C.ink, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DataView<ProductDetailCubit, Product>(
            builder: (context, p) => _Body(product: p),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final prices = product.history.map((e) => e.packPrice).toList();
    final janIndex = product.history.indexWhere((e) => e.date.month == 1);
    final maxMarket = product.byMerchant.isEmpty
        ? 1.0
        : product.byMerchant
              .map((e) => e.packPrice)
              .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: kGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Lbl('SEPETİNDEKİ ÜRÜN'),
          const SizedBox(height: 4),
          Text(product.title, style: T.display),
          const SizedBox(height: 4),
          Text(
            '${product.observations} GÖZLEM · '
            '${product.merchantCount} MARKET · ${product.monthSpan} AY',
            style: T.label.copyWith(fontSize: 10, letterSpacing: .6),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat('İLK GÖRDÜĞÜN', Fmt.money(product.firstPackPrice ?? 0)),
              const SizedBox(width: 22),
              _Stat('ŞİMDİ', Fmt.money(product.lastPackPrice ?? 0)),
              const SizedBox(width: 22),
              _Stat(
                'DEĞİŞİM',
                product.changePct == null
                    ? '—'
                    : Fmt.signedPct0(product.changePct!),
                color: product.changePct == null
                    ? C.muted
                    : (product.changePct! >= 0 ? C.hot : C.ref),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (prices.length >= 2)
            LineChart(
              height: 110,
              series: [ChartSeries(values: prices, color: C.ink, endDot: true)],
              marker: janIndex >= 0 ? janIndex : null,
              markerLabel: janIndex >= 0
                  ? Fmt.monthShort(product.history[janIndex].date)
                  : null,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Grafik için en az iki gözlem gerekiyor.',
                style: TextStyle(fontSize: 11.5, color: C.muted),
              ),
            ),
          const SizedBox(height: 14),
          const Hairline(),
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 4),
            child: Lbl('EN SON GÖRDÜĞÜN FİYATLAR'),
          ),
          for (final m in product.byMerchant)
            _MarketRow(entry: m, fraction: m.packPrice / maxMarket),
          const SizedBox(height: 14),
          Text(
            'Bu ürün endekste ${product.observations} gözlemle temsil '
            'ediliyor. Ağırlığı, senin harcamandaki payına göre.',
            style: const TextStyle(fontSize: 11, height: 1.5, color: C.muted),
          ),
        ],
      ),
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
  const _MarketRow({required this.entry, required this.fraction});
  final MarketPrice entry;
  final double fraction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            entry.market,
            style: const TextStyle(fontSize: 11.5, color: C.ink),
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
                  widthFactor: fraction.clamp(0, 1),
                  child: Container(height: 5, color: C.ink),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            Fmt.money(entry.packPrice),
            textAlign: TextAlign.right,
            style: T.num11,
          ),
        ),
      ],
    ),
  );
}
