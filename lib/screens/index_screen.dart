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
import '../widgets/screen_frame.dart';
import '../state/app_data.dart';
import 'breakdown_screen.dart';
import 'capture_screen.dart';
import 'monthly_card_screen.dart';
import 'official_screen.dart';
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
      title: 'Sepetin',
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
  });

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;
  final BasketCompare basket;
  final int pending;

  /// "SON 12 AY" sabit değil: 12 ay dolmadıysa gerçek pencere yazılıyor,
  /// yıllıklandırma yapılmıyor.
  String get _windowLabel => snapshot.windowMonths >= 12
      ? 'SON 12 AY'
      : 'SON ${snapshot.windowMonths} AY';

  @override
  Widget build(BuildContext context) {
    final delta = snapshot.monthDeltaPoints;

    return Padding(
      padding: kGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Lbl(_windowLabel),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: BigNumber(Fmt.dec1(snapshot.changePct ?? 0)),
          ),
          if (delta != null && delta.abs() >= 0.05)
            DeltaPill(
              text: 'Geçen aya göre ${Fmt.dec1(delta)} puan',
              up: delta >= 0,
            ),
          // Uyarı sayının hemen altında: nitelediği şey o sayı.
          if (pending > 0) ...[
            const SizedBox(height: 14),
            _CoverageNote(pending: pending, receipts: receipts),
          ],
          const SizedBox(height: 16),
          _SourcesCard(snapshot: snapshot, showOwn: true),
          const SizedBox(height: 16),
          LineChart(
            series: [
              ChartSeries(values: snapshot.levels, color: C.ink, endDot: true),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryStrip(
            title: '${Fmt.monthLong(DateTime.now())} özeti',
            sub: 'Paylaşılabilir kartı gör',
            onTap: () => Navigator.of(context).push(MonthlyCardScreen.route()),
          ),
          const SizedBox(height: 8),
          _SummaryStrip(
            title: 'Kırılım',
            sub: 'Hangi kategori, hangi marka',
            onTap: () => Navigator.of(context).push(BreakdownScreen.route()),
          ),
          if (basket.comparable) ...[
            const SizedBox(height: 20),
            const Hairline(),
            const SizedBox(height: 14),
            _BasketCard(basket: basket),
          ],
          const SizedBox(height: 18),
          const Hairline(),
          const SizedBox(height: 12),
          const Lbl('SON FİŞLER'),
          const SizedBox(height: 2),
          for (final r in receipts.take(5))
            Pressable(
              onTap: () =>
                  Navigator.of(context).push(ReceiptDetailScreen.route(r.id)),
              child: LedgerRow(
                name: r.merchant,
                sub:
                    '${Fmt.dayMonth(r.date)} · ${r.itemCount} ÜRÜN'
                    '${r.pendingCount > 0 ? ' · ${r.pendingCount} EŞLEŞME' : ''}',
                amount: Fmt.money(r.total),
              ),
            ),
        ],
      ),
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
          style: const TextStyle(fontSize: 12, height: 1.5, color: C.muted),
        ),
        const SizedBox(height: 10),
        PaperCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length && i < 3; i++) ...[
                if (i > 0) const Hairline(),
                _BasketRow(items[i]),
              ],
            ],
          ),
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
      color: C.card,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
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
                style: T.num12.copyWith(color: C.ref),
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
          color: C.hotBg,
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
                    style: T.title.copyWith(color: C.hot),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Eşleşmesi çözülmeyen satırlar hesabın dışında kalıyor.',
                    style: const TextStyle(fontSize: 11, color: C.hot),
                  ),
                ],
              ),
            ),
            const LineIcon(Glyph.chevron, size: 15, color: C.hot),
          ],
        ),
      ),
    );
  }
}

/// Endeksin altındaki iki kapı: aylık kart ve kırılım.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: PaperCard(
        padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.title),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 11, color: C.muted),
                  ),
                ],
              ),
            ),
            const LineIcon(Glyph.chevron, size: 15, color: C.muted),
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
                  color: C.ink,
                  name: 'Senin sepetin',
                  value: Fmt.pct1(snapshot.changePct ?? 0),
                ),
              for (var i = 0; i < snapshot.official.length; i++) ...[
                if (showOwn || i > 0) const Hairline(),
                SeriesRow(
                  color: snapshot.official[i].official ? C.ref : C.grey,
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
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: C.muted,
                    decoration: TextDecoration.underline,
                    decorationColor: C.line,
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
          const Lbl('SEPETİN'),
          const SizedBox(height: 6),
          Text(
            receipts.isEmpty ? 'İlk fişini ekle' : 'Bir ay daha lazım',
            style: T.display,
          ),
          const SizedBox(height: 8),
          Text(
            receipts.isEmpty
                ? 'Kendi enflasyonun, senin ödediğin fiyatlardan hesaplanıyor. '
                      'Market fişini çek, gerisini uygulama yapıyor.'
                : '${receipts.length} fiş eklendi. Endeks için en az iki '
                      'FARKLI ayda fiş gerekiyor — bir fiyatın değiştiğini '
                      'görebilmek için onu iki kez görmek lazım.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: C.muted,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: receipts.isEmpty ? 'Fiş çek' : 'Fiş ekle',
            onTap: () async {
              final added = await Navigator.of(context)
                  .push<bool>(CaptureScreen.route());
              if (added == true && context.mounted) refreshUserData(context);
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              receipts.isEmpty
                  ? 'Fişin fotoğrafı cihazından çıkmıyor.'
                  : 'Kalan: $need farklı ay',
              style: T.label.copyWith(fontSize: 9.5),
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
          const Text(
            'Senin sayın çıkana kadar resmî ölçüm burada duruyor.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: C.muted),
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
