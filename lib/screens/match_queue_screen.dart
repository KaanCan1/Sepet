import 'package:flutter/cupertino.dart';

import '../state/receipts_cubit.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'receipt_detail_screen.dart';

/// Eşleşme kuyruğu: onay bekleyen satırı olan fişler.
///
/// Kamerayla yakalama henüz yok — cihaz üstü OCR sıradaki adım. Bu ekran o
/// zamana kadar akışın ikinci yarısını çalıştırıyor: okunmuş ama emin
/// olunamamış satırların çözülmesi.
class MatchQueueScreen extends StatelessWidget {
  const MatchQueueScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    fullscreenDialog: true,
    builder: (_) => const MatchQueueScreen(),
  );

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Eşleşmeler',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(
            Glyph.close,
            size: 17,
            color: context.c.muted,
            stroke: 1.6,
          ),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          // Fiş listesini paylaşıyor, yalnızca bekleyeni süzüyor: ayrı bir
          // istek atmasının anlamı yok, üstelik iki liste birbirinden
          // bağımsız tazelenince biri bayatlıyordu.
          child: DataView<ReceiptsCubit, List<Receipt>>(
            isEmpty: (r) => r.where((x) => x.pendingCount > 0).isEmpty,
            empty: const EmptyState(
              title: 'Bekleyen eşleşme yok',
              body:
                  'Bütün fiş satırları bir ürüne bağlandı. Kamerayla fiş '
                  'okuma sıradaki adımda geliyor.',
            ),
            builder: (context, all) {
              final receipts = all.where((r) => r.pendingCount > 0).toList();
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Lbl(
                      '${receipts.fold<int>(0, (a, r) => a + r.pendingCount)} '
                      'SATIR ONAY BEKLİYOR',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bu satırların hangi kanonik ürüne denk geldiğinden emin '
                      'olunamadı. Onayladığın eşleşme kaydedilir ve aynı fiş '
                      'formatı bir daha sorulmaz.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: context.c.muted,
                      ),
                    ),
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
                          sub: '${Fmt.dayMonth(r.date)} · ${r.itemCount} ÜRÜN',
                          amount: '${r.pendingCount}',
                          amountColor: context.c.ref,
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
