import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../state/receipts_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'match_queue_screen.dart';
import 'receipt_detail_screen.dart';

/// Fişler sekmesi — endeksin ham malzemesi.
class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Fişler',
      reserveTabBar: true,
      trailing: Pressable(
        onTap: () => Navigator.of(context).push(MatchQueueScreen.route()),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.check, size: 18, color: C.ink, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DataView<ReceiptsCubit, List<Receipt>>(
            isEmpty: (r) => r.isEmpty,
            empty: const EmptyState(
              title: 'Henüz fiş yok',
              body: 'İlk fişini ekleyince endeksin hesaplanmaya başlar.',
            ),
            builder: (context, receipts) {
              final total = receipts.fold<double>(0, (a, r) => a + r.total);
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Lbl('${receipts.length} FİŞ · TOPLAM'),
                    const SizedBox(height: 6),
                    Text(Fmt.money(total), style: T.display),
                    const SizedBox(height: 16),
                    const Hairline(),
                    const SizedBox(height: 4),
                    for (final r in receipts)
                      Pressable(
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
