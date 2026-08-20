import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/screen_frame.dart';
import 'receipt_detail_screen.dart';

/// Fişler sekmesi — endeksin ham malzemesi.
class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = Mock.receipts.fold<double>(0, (a, r) => a + r.total);

    return ScreenFrame(
      title: 'Fişler',
      reserveTabBar: true,
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 8),
              Lbl(
                '${Fmt.monthLong(Mock.now).toUpperCase()} · '
                '${Mock.receipts.length} FİŞ',
              ),
              const SizedBox(height: 6),
              Text(Fmt.money(total), style: T.display),
              const SizedBox(height: 16),
              const Hairline(),
              const SizedBox(height: 4),
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
