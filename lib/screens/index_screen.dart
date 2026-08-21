import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/async_view.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'monthly_card_screen.dart';
import 'receipt_detail_screen.dart';

/// 01 — Endeks. Uygulamanın cevabı tek sayı; geri kalanı o sayının kanıtı.
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  final _reloader = Reloader();

  @override
  void dispose() {
    _reloader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repoOf(context);

    return ScreenFrame(
      title: 'Sepetin',
      reserveTabBar: true,
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView<(IndexSnapshot, List<Receipt>)>(
            reloadOn: _reloader,
            load: () async => (await repo.index(), await repo.receipts()),
            isEmpty: (d) => d.$1.isEmpty,
            empty: const EmptyState(
              title: 'Henüz endeks yok',
              body:
                  'Endeks en az iki farklı ayda fiş gerektiriyor — bir fiyatın '
                  'değiştiğini görebilmek için önce iki kez görmek lazım.',
            ),
            builder: (context, data) => _Body(
              snapshot: data.$1,
              receipts: data.$2,
              onChanged: _reloader.reload,
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
    required this.onChanged,
  });

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;
  final VoidCallback onChanged;

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
          if (snapshot.official.any((s) => s.value == null))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Resmî ve bağımsız ölçümler henüz çekilmedi.',
                style: TextStyle(fontSize: 11, color: C.muted),
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
            month: Fmt.monthLong(DateTime.now()),
            onTap: () => Navigator.of(context).push(MonthlyCardScreen.route()),
          ),
          const SizedBox(height: 18),
          const Hairline(),
          const SizedBox(height: 12),
          const Lbl('SON FİŞLER'),
          const SizedBox(height: 2),
          for (final r in receipts.take(5))
            Pressable(
              onTap: () async {
                await Navigator.of(context)
                    .push(ReceiptDetailScreen.route(r.id));
                onChanged();
              },
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

/// Ayın 3'ünde gelen bildirimin varış noktası.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.month, required this.onTap});

  final String month;
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
                  Text('$month özeti', style: T.title),
                  const SizedBox(height: 3),
                  const Text(
                    'Paylaşılabilir kartı gör',
                    style: TextStyle(fontSize: 11, color: C.muted),
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
