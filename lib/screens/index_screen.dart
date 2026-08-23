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
import 'breakdown_screen.dart';
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
          child: DataView<IndexCubit, IndexHome>(
            isEmpty: (d) => d.isEmpty,
            empty: const EmptyState(
              title: 'Henüz endeks yok',
              body:
                  'Endeks en az iki farklı ayda fiş gerektiriyor — bir fiyatın '
                  'değiştiğini görebilmek için önce iki kez görmek lazım.',
            ),
            builder: (context, data) =>
                _Body(snapshot: data.snapshot, receipts: data.receipts),
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
    final missing = snapshot.official.where((s) => s.value == null).toList();

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
          PaperCard(
            child: Column(
              children: [
                SeriesRow(
                  color: C.ink,
                  name: 'Senin sepetin',
                  value: Fmt.pct1(snapshot.changePct ?? 0),
                ),
                for (final source in snapshot.official) ...[
                  const Hairline(),
                  SeriesRow(
                    color: source.official ? C.ref : C.grey,
                    name: source.title,
                    // Resmî veri henüz çekilmedi — uydurmuyoruz.
                    value: source.value == null ? '—' : Fmt.pct1(source.value!),
                  ),
                ],
              ],
            ),
          ),
          // Eksik seriyi adıyla söyleyip girişe götürüyor. Eski metin
          // "henüz çekilmedi" diyordu: hem yanlış (çekilmiyorlar, elle
          // giriliyorlar) hem de biri girildiğinde bile aynı kalıyordu.
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
                        : '${missing.map((s) => s.title).join(', ')} için '
                              'ay girilmedi — girmek için dokun.',
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
