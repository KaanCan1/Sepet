import 'package:flutter/cupertino.dart';

import '../data/app_scope.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/async_view.dart';
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
class MatchQueueScreen extends StatefulWidget {
  const MatchQueueScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    fullscreenDialog: true,
    builder: (_) => const MatchQueueScreen(),
  );

  @override
  State<MatchQueueScreen> createState() => _MatchQueueScreenState();
}

class _MatchQueueScreenState extends State<MatchQueueScreen> {
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
      title: 'Eşleşmeler',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.close, size: 17, color: C.muted, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView<List<Receipt>>(
            reloadOn: _reloader,
            load: () async => (await repo.receipts())
                .where((r) => r.pendingCount > 0)
                .toList(),
            isEmpty: (r) => r.isEmpty,
            empty: const EmptyState(
              title: 'Bekleyen eşleşme yok',
              body:
                  'Bütün fiş satırları bir ürüne bağlandı. Kamerayla fiş '
                  'okuma sıradaki adımda geliyor.',
            ),
            builder: (context, receipts) => Padding(
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
                  const Text(
                    'Bu satırların hangi kanonik ürüne denk geldiğinden emin '
                    'olunamadı. Onayladığın eşleşme kaydedilir ve aynı fiş '
                    'formatı bir daha sorulmaz.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: C.muted),
                  ),
                  const SizedBox(height: 16),
                  const Hairline(),
                  const SizedBox(height: 4),
                  for (final r in receipts)
                    Pressable(
                      onTap: () async {
                        await Navigator.of(context)
                            .push(ReceiptDetailScreen.route(r.id));
                        _reloader.reload();
                      },
                      child: LedgerRow(
                        name: r.merchant,
                        sub: '${Fmt.dayMonth(r.date)} · ${r.itemCount} ÜRÜN',
                        amount: '${r.pendingCount}',
                        amountColor: C.ref,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
