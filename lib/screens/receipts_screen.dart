import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';
import '../data/fmt.dart';
import '../data/repository.dart';
import '../state/app_data.dart';
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
                    for (final r in receipts) _SwipeToDelete(receipt: r),
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

/// Sola kaydırınca silme çıkan fiş satırı.
///
/// Yanlışlıkla onaylanan bir fiş için tek çare "hepsini sil" olmamalı.
/// Kaydırma tek başına silmiyor: fiş endeksi değiştirdiği için geri
/// alınamayan bir işlem ve ayrıca onay isteniyor.
class _SwipeToDelete extends StatelessWidget {
  const _SwipeToDelete({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(receipt.id),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: C.hot,
        child: const Text('Sil', style: TextStyle(fontSize: 13, color: C.card)),
      ),
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) => _delete(context),
      child: Pressable(
        onTap: () =>
            Navigator.of(context).push(ReceiptDetailScreen.route(receipt.id)),
        child: LedgerRow(
          name: receipt.merchant,
          sub:
              '${Fmt.dayMonth(receipt.date)} · ${receipt.itemCount} ÜRÜN'
              '${receipt.pendingCount > 0 ? ' · ${receipt.pendingCount} EŞLEŞME' : ''}',
          amount: Fmt.money(receipt.total),
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Fişi sil', style: T.title),
        content: Text(
          '${receipt.merchant} · ${Fmt.dayMonth(receipt.date)} · '
          '${Fmt.money(receipt.total)}\n\n'
          'Bu fişin satırları ve fiyat gözlemleri silinir, endeks yeniden '
          'hesaplanır. Bu işlem geri alınamaz.',
          style: const TextStyle(fontSize: 12.5, height: 1.5, color: C.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: C.hot)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete(BuildContext context) async {
    final repo = context.read<Repository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.deleteReceipt(receipt.id);
      if (context.mounted) refreshUserData(context);
      messenger.showSnackBar(_snack('Fiş silindi'));
    } on ApiException catch (e) {
      // Silme başarısızsa satır listeden gitmiş olacak; listeyi tazeleyip
      // fişi geri getiriyoruz — kullanıcı silindi sanmasın.
      if (context.mounted) refreshUserData(context);
      messenger.showSnackBar(_snack(e.message));
    }
  }

  SnackBar _snack(String text) => SnackBar(
    backgroundColor: C.ink,
    behavior: SnackBarBehavior.floating,
    content: Text(text, style: const TextStyle(fontSize: 12.5, color: C.card)),
  );
}
