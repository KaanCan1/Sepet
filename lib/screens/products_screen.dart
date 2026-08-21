import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/async_view.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/screen_frame.dart';
import 'product_screen.dart';

/// Ürünler sekmesi — sepetteki kanonik ürünler ve değişimleri.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repoOf(context);

    return ScreenFrame(
      title: 'Sepetindeki ürünler',
      reserveTabBar: true,
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView<List<Product>>(
            load: repo.products,
            isEmpty: (p) => p.isEmpty,
            empty: const EmptyState(
              title: 'Sepetin boş',
              body:
                  'Fiş ekledikçe aldığın ürünler burada birikir ve her birinin '
                  'fiyat geçmişi çıkar.',
            ),
            builder: (context, products) => Padding(
              padding: kGutter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Lbl('BİRİM FİYAT DEĞİŞİMİNE GÖRE'),
                  const SizedBox(height: 10),
                  for (final p in products) ...[
                    Pressable(
                      onTap: () =>
                          Navigator.of(context).push(ProductScreen.route(p.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.listTitle,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: C.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${p.observations} GÖZLEM · '
                                    '${p.merchantCount} MARKET',
                                    style: T.label,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text(
                                p.changePct == null
                                    ? '—'
                                    : Fmt.signedPct0(p.changePct!),
                                textAlign: TextAlign.right,
                                style: T.num12.copyWith(
                                  color: p.changePct == null
                                      ? C.muted
                                      : (p.changePct! >= 0 ? C.hot : C.ref),
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
          ),
        ),
      ],
    );
  }
}
