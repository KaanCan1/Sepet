import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/screen_frame.dart';
import 'product_screen.dart';

/// Ürünler sekmesi — sepetteki kanonik ürünler ve 12 aylık değişimleri.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Product>.of(Mock.products)
      ..sort((a, b) => b.changePct.compareTo(a.changePct));

    return ScreenFrame(
      title: 'Sepetindeki ürünler',
      reserveTabBar: true,
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 8),
              const Lbl('12 AYLIK DEĞİŞİME GÖRE'),
              const SizedBox(height: 10),
              for (final p in sorted) ...[
                Pressable(
                  onTap: () =>
                      Navigator.of(context).push(ProductScreen.route(p)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.name}, ${p.size}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: C.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${p.observations} GÖZLEM · '
                                '${p.marketCount} MARKET',
                                style: T.label,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 58,
                          child: LineChart(
                            height: 24,
                            series: [
                              ChartSeries(
                                values: p.history.map((e) => e.price).toList(),
                                color: p.changePct >= 0 ? C.ink : C.ref,
                                width: 1.4,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            Fmt.signedPct0(p.changePct),
                            textAlign: TextAlign.right,
                            style: T.num12.copyWith(
                              color: p.changePct >= 0 ? C.hot : C.ref,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Hairline(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
