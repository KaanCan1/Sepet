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
      slivers: [
        SliverToBoxAdapter(
          // Boş durum DataView'a bırakılmıyor: o yalnızca ortada bir metin
          // gösteriyor ve ekran bomboş kalıyordu — kullanıcı ne yapacağını
          // göremiyordu. _FirstRun hem yapılacak işi hem de karşılaştırma
          // çizgisini gösteriyor.
          child: DataView<IndexCubit, IndexHome>(
            builder: (context, data) => data.isEmpty
                ? _FirstRun(snapshot: data.snapshot, receipts: data.receipts)
                : _Body(snapshot: data.snapshot, receipts: data.receipts),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot, required this.receipts});

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;

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
  const _FirstRun({required this.snapshot, required this.receipts});

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;

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
