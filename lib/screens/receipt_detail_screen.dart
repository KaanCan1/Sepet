import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/async_view.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/match_sheet.dart';
import '../widgets/receipt_paper.dart';
import '../widgets/screen_frame.dart';

/// Fişin satır kırılımı ve eşleşme onayı.
///
/// Projenin kalbi buradaki `eşleşme?` etiketi: normalizasyon emin olamadığı
/// satırı kullanıcıya soruyor, böylece her satır için model çağırmak
/// gerekmiyor ve yanlış eşleşme endeksi sessizce bozmuyor.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final String receiptId;

  static Route<void> route(String id) =>
      CupertinoPageRoute(builder: (_) => ReceiptDetailScreen(receiptId: id));

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final _reloader = Reloader();

  @override
  void dispose() {
    _reloader.dispose();
    super.dispose();
  }

  Future<void> _resolve(ReceiptLine line) async {
    final productId = await MatchSheet.show(context, line);
    if (productId == null || !mounted) return;

    final repo = AppScope.repoOf(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.confirmMatch(
        receiptId: widget.receiptId,
        lineId: line.id,
        productId: productId,
      );
      _reloader.reload();
      dataChanged.reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '$e',
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repoOf(context);

    return ScreenFrame(
      title: 'Fiş',
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.back, size: 17, color: C.ink, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView<Receipt>(
            reloadOn: _reloader,
            load: () => repo.receipt(widget.receiptId),
            builder: (context, receipt) {
              final pending = receipt.lines.where((l) => l.needsMatch).length;
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Lbl(
                      '${Fmt.dayMonth(receipt.date)} ${receipt.date.year} · '
                      '${receipt.itemCount} ÜRÜN',
                    ),
                    const SizedBox(height: 4),
                    Text(receipt.merchant, style: T.display),
                    const SizedBox(height: 20),
                    // Önce kâğıt hâli, sonra yorumlanmış hâli. İkisinin yan
                    // yana durması eşleşmenin ne demek olduğunu anlatıyor.
                    ReceiptPaper(receipt: receipt),
                    const SizedBox(height: 26),
                    Lbl(
                      pending > 0
                          ? '${receipt.lines.length} SATIR · '
                                '$pending EŞLEŞME ONAYI BEKLİYOR'
                          : '${receipt.lines.length} SATIR · HEPSİ EŞLEŞTİ',
                    ),
                    const SizedBox(height: 8),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < receipt.lines.length; i++) ...[
                            if (i > 0) const Hairline(),
                            _LineRow(
                              line: receipt.lines[i],
                              onTap: receipt.lines[i].needsMatch
                                  ? () => _resolve(receipt.lines[i])
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (pending > 0) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'İşaretli satırlarda hangi kanonik ürüne denk geldiğinden '
                        'emin olunamadı. Onayladığın eşleşme kaydedilir; aynı fiş '
                        'formatı bir daha sorulmaz.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: C.muted,
                        ),
                      ),
                    ],
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

/// Kanonik ad üstte, fişteki ham satır altta, tutar sağda.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.onTap});

  final ReceiptLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        color: C.card,
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        line.canonical ?? line.raw,
                        style: TextStyle(
                          fontSize: 11,
                          color: line.canonical == null ? C.muted : C.ink,
                        ),
                      ),
                      if (line.needsMatch) const MatchFlag(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(line.rawLine, style: T.raw),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(Fmt.money(line.amount), style: T.num11),
          ],
        ),
      ),
    );
  }
}
