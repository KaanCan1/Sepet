import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../state/products_cubit.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/screen_frame.dart';
import 'product_screen.dart';

/// Ürünler sekmesi — sepetteki kanonik ürünler ve değişimleri.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showTopBar: false,
      reserveTabBar: true,
      slivers: [
        SliverToBoxAdapter(
          child: DataView<ProductsCubit, List<Product>>(
            isEmpty: (p) => p.isEmpty,
            empty: const EmptyState(
              title: 'Sepetin boş',
              body:
                  'Fiş ekledikçe aldığın ürünler burada birikir ve her birinin '
                  'fiyat geçmişi çıkar.',
            ),
            builder: (context, products) {
              final c = context.c;
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Printed(
                      step: 0,
                      child: LargeTitle(
                        'Ürünler',
                        trailing: '${products.length} ÜRÜN',
                      ),
                    ),
                    Printed(
                      step: 1,
                      child: Lbl('BİRİM FİYAT DEĞİŞİMİNE GÖRE', color: c.faint),
                    ),
                    for (final (i, p) in products.indexed)
                      Printed(
                        step: 2 + i,
                        child: _ProductRow(product: p),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Ürün satırı: ad, gözlem sayısı, satır içi kıvılcım ve değişim.
///
/// Kıvılcım rengini üründen alıyor — listede hangi kalemin yükseldiği
/// sayıyı okumadan görünüyor.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = product.changePct;
    final color = c.category[categoryIndex(product.listTitle)];

    return Pressable(
      onTap: () => Navigator.of(context).push(ProductScreen.route(product.id)),
      scale: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.listTitle,
                    style: T.rowName.copyWith(fontSize: 13, color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${product.observations} GÖZLEM · '
                    '${product.merchantCount} MARKET',
                    style: T.label.copyWith(fontSize: 8.5, color: c.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Kıvılcım birim fiyattan çiziliyor, paket fiyatından değil:
            // paket boyu değişince paket fiyatı yanıltıyor.
            if (product.history.length >= 2)
              SizedBox(
                width: 56,
                child: LineChart(
                  height: 22,
                  guides: false,
                  series: [
                    ChartSeries(
                      values: [for (final h in product.history) h.unitPrice],
                      color: color,
                      width: 1.8,
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              child: Text(
                pct == null ? '—' : Fmt.signedPct0(pct),
                textAlign: TextAlign.right,
                style: T.value.copyWith(color: pct == null ? c.faint : color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
