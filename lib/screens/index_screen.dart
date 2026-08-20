import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../theme/tokens.dart';
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

class _IndexScreenState extends State<IndexScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Sepetin',
      reserveTabBar: true,
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 8),
              const Lbl('SON 12 AY'),
              AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final t = Curves.easeOutCubic.transform(_c.value);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: BigNumber(Fmt.dec1(Mock.headline * t)),
                  );
                },
              ),
              Row(
                children: [
                  DeltaPill(
                    text: 'Geçen aya göre ${Fmt.dec1(Mock.monthDelta)} puan',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  children: [
                    for (var i = 0; i < Mock.series.length; i++) ...[
                      if (i > 0) const Hairline(),
                      SeriesRow(
                        color: Mock.series[i].color,
                        name: Mock.series[i].name,
                        value: Fmt.pct1(Mock.series[i].value),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _c,
                builder: (_, __) => LineChart(
                  height: 96,
                  progress: Curves.easeOutCubic.transform(_c.value),
                  series: [
                    ChartSeries(
                      values: Mock.series[0].points,
                      color: C.ink,
                      width: 1.8,
                      endDot: true,
                    ),
                    ChartSeries(
                      values: Mock.series[1].points,
                      color: C.ref,
                      width: 1.4,
                      dashed: true,
                    ),
                    ChartSeries(
                      values: Mock.series[2].points,
                      color: C.grey,
                      width: 1.2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SummaryStrip(
                month: Fmt.monthLong(Mock.now),
                onTap: () =>
                    Navigator.of(context).push(MonthlyCardScreen.route()),
              ),
              const SizedBox(height: 18),
              const Hairline(),
              const SizedBox(height: 12),
              const Lbl('SON FİŞLER'),
              const SizedBox(height: 2),
              for (final r in Mock.receipts)
                Pressable(
                  onTap: () =>
                      Navigator.of(context).push(ReceiptDetailScreen.route(r)),
                  child: LedgerRow(
                    name: r.heading,
                    sub: '${Fmt.dayMonth(r.date)} · ${r.itemCount} ÜRÜN',
                    amount: Fmt.money(r.total),
                  ),
                ),
            ],
          ),
        ),
      ],
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
