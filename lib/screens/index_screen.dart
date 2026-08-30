import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/index_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/motion.dart';
import '../widgets/screen_frame.dart';
import '../state/app_data.dart';
import 'breakdown_screen.dart';
import 'capture_screen.dart';
import 'monthly_card_screen.dart';
import 'official_screen.dart';
import 'product_screen.dart';
import 'receipt_detail_screen.dart';

/// 01 — Endeks. Uygulamanın cevabı tek sayı; geri kalanı o sayının kanıtı.
///
/// Veri IndexCubit'te ve cubit kabuğun üstünde duruyor: fiş eklendiğinde
/// buradaki sayı da fiş listesi de bayatlıyor, ikisi ekrana bağlı olsaydı
/// sekme değiştirmeden tazelenemezlerdi.
class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showTopBar: false,
      reserveTabBar: true,
      onRefresh: () => refreshUserData(context),
      slivers: [
        SliverToBoxAdapter(
          // Boş durum DataView'a bırakılmıyor: o yalnızca ortada bir metin
          // gösteriyor ve ekran bomboş kalıyordu — kullanıcı ne yapacağını
          // göremiyordu. _FirstRun hem yapılacak işi hem de karşılaştırma
          // çizgisini gösteriyor.
          child: DataView<IndexCubit, IndexHome>(
            builder: (context, data) => data.isEmpty
                ? _FirstRun(
                    snapshot: data.snapshot,
                    receipts: data.receipts,
                    basket: data.basket,
                    pending: data.pendingLines,
                  )
                : _Body(
                    snapshot: data.snapshot,
                    receipts: data.receipts,
                    basket: data.basket,
                    pending: data.pendingLines,
                    movers: data.movers,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.snapshot,
    required this.receipts,
    required this.basket,
    required this.pending,
    required this.movers,
  });

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;
  final BasketCompare basket;
  final int pending;
  final List<Mover> movers;

  /// "SON 12 AY" sabit değil: 12 ay dolmadıysa gerçek pencere yazılıyor,
  /// yıllıklandırma yapılmıyor.
  String get _windowLabel => snapshot.windowMonths >= 12
      ? 'SON 12 AY'
      : 'SON ${snapshot.windowMonths} AY';

  @override
  Widget build(BuildContext context) {
    final delta = snapshot.monthDeltaPoints;
    // Değeri olmayan seri de gösteriliyor: tire koyup elle girilebileceğini
    // söylemek, satırı hiç çizmemekten iyi. Uydurmuyoruz ama saklamıyoruz da.
    final tuik = snapshot.official.firstOrNull;
    final own = snapshot.changePct ?? 0;
    final top = movers.take(3).toList();
    final peak = top.isEmpty ? 1.0 : top.first.pct.abs();
    final c = context.c;

    // Kutu yok: ayırma işini boşluk ve ince çizgi yapıyor. Sıra cevabın
    // sırası — önce sayı, sonra resmî ölçümle farkı, sonra kanıtı.
    return Padding(
      padding: kGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Printed(
            step: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LargeTitle(
                  'Sepetin',
                  trailing: Fmt.monthLong(DateTime.now()).toUpperCase(),
                ),
                Lbl(_windowLabel, color: c.faint),
                const SizedBox(height: 4),
                BigNumber(Fmt.dec1(own)),
                if (delta != null && delta.abs() >= 0.05) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${delta >= 0 ? '▲' : '▼'} ${Fmt.dec1(delta.abs())} PUAN BU AY',
                    style: T.label.copyWith(fontSize: 10, color: c.hot),
                  ),
                ],
                if (tuik != null) ...[
                  CompareRow(
                    label: tuik.title,
                    value: tuik.value == null ? '—' : Fmt.pct1(tuik.value!),
                    difference: tuik.value == null
                        ? null
                        : _gap(own, tuik.value!),
                  ),
                  if (tuik.value == null)
                    Pressable(
                      onTap: () =>
                          Navigator.of(context).push(OfficialScreen.route()),
                      scale: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Resmî ölçüm elle giriliyor — girmek için dokun.',
                          style: T.body.copyWith(
                            fontSize: 11.5,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (pending > 0)
            Printed(
              step: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _CoverageNote(pending: pending, receipts: receipts),
              ),
            ),
          const SizedBox(height: 16),
          // Çizgi solmuyor, çiziliyor: yatay eksen zaman.
          DrawnLineChart(
            delay: M.stagger * 2,
            height: 116,
            series: [
              ChartSeries(
                values: snapshot.levels,
                color: c.ink,
                width: 2.4,
                endDot: true,
                fill: c.ink.withValues(alpha: c.areaFade),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Printed(step: 3, child: _MonthAxis(count: snapshot.levels.length)),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 30),
            Printed(
              step: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Lbl('EN ÇOK ARTAN', color: c.faint)),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).push(BreakdownScreen.route()),
                    child: Text(
                      'Tümü →',
                      style: T.body.copyWith(fontSize: 11.5, color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, m) in top.indexed)
              Printed(
                step: 5 + i,
                child: StatRow(
                  step: i,
                  name: m.title,
                  value: Fmt.signedPct1(m.pct),
                  ratio: peak == 0 ? 0 : m.pct.abs() / peak,
                  color: c.category[categoryIndex(m.name)],
                  onTap: () =>
                      Navigator.of(context)
                          .push(ProductScreen.route(m.productId)),
                ),
              ),
          ],
          if (basket.comparable)
            Printed(
              step: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  _BasketCard(basket: basket),
                ],
              ),
            ),
          const SizedBox(height: 26),
          Printed(
            step: 9,
            child: Column(
              children: [
                ActionRow(
                  label: 'Kırılım',
                  hint: 'KATEGORİ · MARKA',
                  onTap: () =>
                      Navigator.of(context).push(BreakdownScreen.route()),
                ),
                ActionRow(
                  label: '${Fmt.monthLong(DateTime.now())} kartı',
                  hint: 'PAYLAŞ',
                  onTap: () =>
                      Navigator.of(context).push(MonthlyCardScreen.route()),
                ),
              ],
            ),
          ),
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 26),
            Printed(step: 10, child: Lbl('SON FİŞLER', color: c.faint)),
            for (final (i, r) in receipts.take(4).indexed)
              Printed(
                step: 11 + i,
                child: Pressable(
                  onTap: () =>
                      Navigator.of(context)
                          .push(ReceiptDetailScreen.route(r.id)),
                  child: LedgerRow(
                    name: r.merchant,
                    sub:
                        '${Fmt.dayMonth(r.date)} · ${r.itemCount} ÜRÜN'
                        '${r.pendingCount > 0 ? ' · ${r.pendingCount} EŞLEŞME' : ''}',
                    amount: Fmt.money(r.total),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// "TÜİK'ten 3,6 puan altında" — kullanıcının asıl sorusunun cevabı.
  String _gap(double own, double official) {
    final d = official - own;
    if (d.abs() < 0.05) return 'AYNI SEVİYEDE';
    return '${Fmt.dec1(d.abs())} PUAN ${d > 0 ? 'ALTINDA' : 'ÜSTÜNDE'}';
  }
}

/// Grafiğin altındaki ay ekseni. Beş etiket: ikisi uç, üçü arada.
class _MonthAxis extends StatelessWidget {
  const _MonthAxis({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final now = DateTime.now();
    final picks = {0, count ~/ 4, count ~/ 2, count * 3 ~/ 4, count - 1};
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final i in picks)
          Text(
            Fmt.monthShort(DateTime(now.year, now.month - (count - 1 - i))),
            style: T.label.copyWith(fontSize: 8, color: context.c.faint),
          ),
      ],
    );
  }
}

/// Son sepetin karşılaştırması — endeksin doldurmadığı boşluk.
///
/// Endeks iki FARKLI ayda fiş istiyor: bir fiyatın değiştiğini görmek için
/// onu iki kez görmek gerekiyor. İlk günlerde ekran bu yüzden "bir ay daha
/// lazım" yazıp duruyordu ve kullanıcının eline hiçbir şey geçmiyordu.
///
/// Buradaki sayı endeks değil, kayıp: aynı kalemleri daha önce daha ucuza
/// görmüş olmanın parasal karşılığı. Endeks uzun vadeli bir vaat; bu ilk
/// günden karşılığı olan bir vaat.
///
/// Kıyaslanan her kalemin yanında alternatifin marketi ve TARİHİ yazıyor.
/// Sayının kaynağını göstermeden "şu kadar kaybettin" demek, kullanıcıdan
/// doğrulayamayacağı bir şeye inanmasını istemek olurdu.
class _BasketCard extends StatelessWidget {
  const _BasketCard({required this.basket});

  final BasketCompare basket;

  @override
  Widget build(BuildContext context) {
    final items = basket.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Lbl('DAHA UCUZA GÖRMÜŞTÜN'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(Fmt.money(basket.saved), style: T.display),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('TL', style: T.label),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          // Fişin tamamı değil, kıyaslanabilen kalemler. "Sepetin toplamı"
          // demek yanlış olurdu — kalan kalemler için elimizde veri yok.
          '${basket.merchant} fişindeki ${basket.itemCount} kalemi daha önce '
          'gördüğün en ucuz yerlerden alsaydın bu kadar az öderdin.',
          style: T.body.copyWith(
            fontSize: 12,
            height: 1.5,
            color: context.c.muted,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < items.length && i < 3; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.c.line)),
            ),
            child: _BasketRow(items[i]),
          ),
        if (items.length > 3) ...[
          const SizedBox(height: 7),
          Text(
            've ${items.length - 3} kalem daha',
            style: T.label.copyWith(fontSize: 9.5),
          ),
        ],
      ],
    );
  }
}

class _BasketRow extends StatelessWidget {
  const _BasketRow(this.item);

  final BasketItem item;

  @override
  Widget build(BuildContext context) {
    // Aynı ürünse ayırt eden şey market; farklıysa markanın kendisi de
    // bilgi — "Şenpiliç yerine Banvit" başka bir karar.
    final alt = item.sameProduct
        ? '${item.bestMerchant} · ${Fmt.dayMonth(item.bestSeenOn)}'
        : '${item.bestName} · ${item.bestMerchant} · '
              '${Fmt.dayMonth(item.bestSeenOn)}';

    return Container(
      padding: const EdgeInsets.only(top: 11, bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: T.title),
                const SizedBox(height: 3),
                Text(alt, style: T.raw),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(item.paid), style: T.num12),
              const SizedBox(height: 3),
              Text(
                '−${Fmt.money(item.saved)}',
                style: T.num12.copyWith(color: context.c.ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "N kalem endekse girmiyor."
///
/// Eşleşmeyen satır sessizce kapsam dışında kalıyordu: endeks doğru ama
/// eksik bir sepetten hesaplanıyordu ve bunu söyleyen hiçbir şey yoktu.
/// Kullanıcı fişi eklerken "sonra hallederim" dediğinde o "sonra" hiç
/// gelmiyordu, çünkü hatırlatan yoktu.
class _CoverageNote extends StatelessWidget {
  const _CoverageNote({required this.pending, required this.receipts});

  final int pending;
  final List<Receipt> receipts;

  @override
  Widget build(BuildContext context) {
    final hedef = receipts.firstWhere((r) => r.pendingCount > 0);

    return Pressable(
      onTap: () =>
          Navigator.of(context).push(ReceiptDetailScreen.route(hedef.id)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 11, 11),
        decoration: BoxDecoration(
          color: context.c.hotBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pending kalem endekse girmiyor',
                    style: T.title.copyWith(color: context.c.hot),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Eşleşmesi çözülmeyen satırlar hesabın dışında kalıyor.',
                    style: TextStyle(fontSize: 11, color: context.c.hot),
                  ),
                ],
              ),
            ),
            LineIcon(Glyph.chevron, size: 15, color: context.c.hot),
          ],
        ),
      ),
    );
  }
}

/// Karşılaştırma kartı. Endeks varken kendi sayınla birlikte, ilk açılışta
/// tek başına — resmî çizgi kullanıcının verisine bağlı değil.
class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.snapshot, required this.showOwn});

  final IndexSnapshot snapshot;
  final bool showOwn;

  @override
  Widget build(BuildContext context) {
    final missing = snapshot.official.where((s) => s.value == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperCard(
          child: Column(
            children: [
              if (showOwn)
                SeriesRow(
                  color: context.c.ink,
                  name: 'Senin sepetin',
                  value: Fmt.pct1(snapshot.changePct ?? 0),
                ),
              for (var i = 0; i < snapshot.official.length; i++) ...[
                if (showOwn || i > 0) const Hairline(),
                SeriesRow(
                  color: snapshot.official[i].official
                      ? context.c.ref
                      : context.c.grey,
                  name: snapshot.official[i].title,
                  // Girilmemiş ay uydurulmuyor.
                  value: snapshot.official[i].value == null
                      ? '—'
                      : Fmt.pct1(snapshot.official[i].value!),
                ),
              ],
            ],
          ),
        ),
        // Eksik seriyi adıyla söyleyip girişe götürüyor.
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Pressable(
              onTap: () => Navigator.of(context).push(OfficialScreen.route()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  missing.length == snapshot.official.length
                      ? 'Karşılaştırma serileri elle giriliyor — girmek '
                            'için dokun.'
                      : '${missing.map((s) => s.title).join(', ')} için ay '
                            'girilmedi — girmek için dokun.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: context.c.muted,
                    decoration: TextDecoration.underline,
                    decorationColor: context.c.line,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Endeks henüz hesaplanamıyorken görünen ekran.
///
/// Eskiden burada ortalanmış iki satır metin vardı ve ekranın geri kalanı
/// bomboştu: fişini silen ya da yeni giren kullanıcı ne yapacağını
/// göremiyordu. Şimdi üç şey var — kaç fiş kaldığı, tek bir birincil eylem,
/// ve zaten bağımsız olan karşılaştırma çizgisi.
class _FirstRun extends StatelessWidget {
  const _FirstRun({
    required this.snapshot,
    required this.receipts,
    required this.basket,
    required this.pending,
  });

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;
  final BasketCompare basket;
  final int pending;

  /// Endeks iki FARKLI ayda fiş istiyor: bir fiyatın değiştiğini görmek için
  /// onu iki kez görmek gerekiyor.
  int get _monthsCovered =>
      receipts.map((r) => '${r.date.year}-${r.date.month}').toSet().length;

  @override
  Widget build(BuildContext context) {
    final need = 2 - _monthsCovered;

    return Padding(
      padding: kGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Printed(
            step: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Lbl('SEPETİN'),
                const SizedBox(height: 6),
                Text(
                  receipts.isEmpty ? 'İlk fişini ekle' : 'Bir ay daha lazım',
                  style: T.display,
                ),
                const SizedBox(height: 8),
                Text(
                  receipts.isEmpty
                      ? 'Kendi enflasyonun, senin ödediğin fiyatlardan '
                            'hesaplanıyor. Market fişini çek, gerisini '
                            'uygulama yapıyor.'
                      : '${receipts.length} fiş eklendi. Endeks için en az iki '
                            'FARKLI ayda fiş gerekiyor — bir fiyatın '
                            'değiştiğini görebilmek için onu iki kez görmek '
                            'lazım.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: context.c.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Printed(
            step: 1,
            child: PrimaryButton(
              label: receipts.isEmpty ? 'Fiş çek' : 'Fiş ekle',
              onTap: () async {
                final added = await Navigator.of(context)
                    .push<bool>(CaptureScreen.route());
                if (added == true && context.mounted) refreshUserData(context);
              },
            ),
          ),
          const SizedBox(height: 10),
          Printed(
            step: 2,
            child: Center(
              child: Text(
                receipts.isEmpty
                    ? 'Fişin fotoğrafı cihazından çıkmıyor.'
                    : 'Kalan: $need farklı ay',
                style: T.label.copyWith(fontSize: 9.5),
              ),
            ),
          ),
          // Endeks olgunlaşana kadar ekranın söyleyebildiği tek somut şey
          // burada, birincil eylemin hemen altında duruyor.
          if (basket.comparable) ...[
            const SizedBox(height: 26),
            const Hairline(),
            const SizedBox(height: 14),
            _BasketCard(basket: basket),
          ],
          if (pending > 0) ...[
            const SizedBox(height: 18),
            _CoverageNote(pending: pending, receipts: receipts),
          ],
          const SizedBox(height: 26),
          const Hairline(),
          const SizedBox(height: 14),
          const Lbl('KARŞILAŞTIRMA'),
          const SizedBox(height: 6),
          Text(
            'Senin sayın çıkana kadar resmî ölçüm burada duruyor.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: context.c.muted,
            ),
          ),
          const SizedBox(height: 10),
          _SourcesCard(snapshot: snapshot, showOwn: false),
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Hairline(),
            const SizedBox(height: 12),
            const Lbl('EKLEDİĞİN FİŞLER'),
            const SizedBox(height: 2),
            for (final r in receipts.take(5))
              Pressable(
                onTap: () =>
                    Navigator.of(context).push(ReceiptDetailScreen.route(r.id)),
                child: LedgerRow(
                  name: r.merchant,
                  sub: '${Fmt.dayMonth(r.date)} · ${r.itemCount} ÜRÜN',
                  amount: Fmt.money(r.total),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
