import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../data/text_fold.dart';
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
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _arama = TextEditingController();

  /// Kutuya yazılanın katlanmış hâli. Her karede yeniden hesaplamamak için
  /// burada duruyor.
  String _sorgu = '';

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  /// Ad ve boy birlikte aranıyor: kullanıcı "sut 1 litre" de yazabiliyor,
  /// "1 litre" de. Ayrı ayrı arasaydık ikincisi hiçbir şey bulmazdı.
  List<Product> _suz(List<Product> hepsi) {
    if (_sorgu.isEmpty) return hepsi;
    return hepsi
        .where((p) => searchFold('${p.name} ${p.sizeLabel}').contains(_sorgu))
        .toList();
  }

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
              final gorunen = _suz(products);
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Printed(
                      step: 0,
                      child: LargeTitle(
                        'Ürünler',
                        // Süzerken kaç ürün olduğu değil, kaçının kaldığı
                        // önemli.
                        trailing: _sorgu.isEmpty
                            ? '${products.length} ÜRÜN'
                            : '${gorunen.length}/${products.length}',
                      ),
                    ),
                    // Arama kutusu yalnızca liste uzunken görünüyor. Beş
                    // ürünün üstünde bir arama kutusu, aramayı kolaylaştırmak
                    // yerine ekranı meşgul ediyor.
                    if (products.length >= _aramaEsigi)
                      Printed(
                        step: 1,
                        child: _AramaKutusu(
                          controller: _arama,
                          onChanged: (q) =>
                              setState(() => _sorgu = searchFold(q.trim())),
                        ),
                      ),
                    Printed(
                      step: 2,
                      child: Lbl('BİRİM FİYAT DEĞİŞİMİNE GÖRE', color: c.faint),
                    ),
                    if (gorunen.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 26),
                        child: Text(
                          'Bu aramaya uyan ürün yok. Sepette yalnızca fişini '
                          'eklediğin ürünler var.',
                          style: T.body.copyWith(fontSize: 12, color: c.muted),
                        ),
                      ),
                    for (final (i, p) in gorunen.indexed)
                      Printed(
                        step: 3 + i,
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

/// Arama kutusunun görünmeye başladığı ürün sayısı.
///
/// Altında kutu ekrana yük oluyor: liste zaten tek bakışta okunuyor.
const _aramaEsigi = 12;

/// Alt çizgili arama kutusu — uygulamanın diğer alanlarıyla aynı dil.
class _AramaKutusu extends StatelessWidget {
  const _AramaKutusu({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Ürün ara',
          hintStyle: TextStyle(fontSize: 13.5, color: c.muted),
          isDense: true,
          contentPadding: const EdgeInsets.only(bottom: 9),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: c.line),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: c.ink),
          ),
        ),
        style: TextStyle(fontSize: 13.5, color: c.ink),
      ),
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
