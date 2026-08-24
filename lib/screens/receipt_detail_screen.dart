import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository.dart';
import '../state/app_data.dart';
import '../state/receipts_cubit.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
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

  /// Ayrıntı cubit'i yönlendirmeyle doğup ölüyor.
  static Route<void> route(String id) => CupertinoPageRoute(
    builder: (context) => BlocProvider(
      create: (_) => ReceiptDetailCubit(context.read<Repository>(), id)..load(),
      child: ReceiptDetailScreen(receiptId: id),
    ),
  );

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  /// Bekleyen satırları sırayla açar. Kullanıcı fişe her dönüp yeniden
  /// dokunmak yerine tek akışta bitiriyor; vazgeçerse akış da duruyor.
  Future<void> _resolveAll(List<ReceiptLine> lines) async {
    for (final line in lines) {
      if (!mounted) return;
      final done = await _resolve(line);
      if (!done) return;
    }
  }

  Future<bool> _resolve(ReceiptLine line) async {
    final productId = await MatchSheet.show(context, line);
    if (productId == null || !mounted) return false;

    final repo = context.read<Repository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.confirmMatch(
        receiptId: widget.receiptId,
        lineId: line.id,
        productId: productId,
      );
      // Eşleşme sunucuya yazıldı ama ekran kapandıysa akış da duruyor.
      if (!mounted) return false;
      // Bu ekran kendini, sekmeler de kendilerini tazeliyor: onaylanan
      // eşleşme hem fişi hem endeksi değiştiriyor.
      await context.read<ReceiptDetailCubit>().load(silent: true);
      if (mounted) refreshUserData(context);
      return true;
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
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: DataView<ReceiptDetailCubit, Receipt>(
            builder: (context, receipt) {
              final waiting = receipt.lines.where((l) => l.needsMatch).toList();
              final pending = waiting.length;
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
                    Lbl('${receipt.lines.length} SATIR'),
                    const SizedBox(height: 8),
                    if (pending > 0) ...[
                      _PendingBanner(
                        count: pending,
                        onTap: () => _resolveAll(waiting),
                      ),
                      const SizedBox(height: 10),
                    ],
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

/// Bekleyen satırların sayacı ve tek dokunuşta hepsini gezen akış.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: C.hotBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0x389F2F2D)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count kalem eşleşme bekliyor',
                style: const TextStyle(fontSize: 12.5, color: C.hot),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x669F2F2D)),
              ),
              child: Text('SIRAYLA ÇÖZ', style: T.label.copyWith(color: C.hot)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kanonik ad üstte, fişteki ham satır altta, tutar sağda.
///
/// Durum şeritle veriliyor: bekleyen satır zam kırmızısı zemin ve sol
/// şerit alıyor, çözülmüş satır hiçbir işaret taşımıyor. Kasa poşeti gibi
/// endeks dışı kalemler ise sessiz — sorulacak bir şey yok.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.onTap});

  final ReceiptLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final waiting = line.needsMatch;
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        decoration: BoxDecoration(
          color: waiting ? C.hotBg : C.card,
          border: waiting
              ? const Border(left: BorderSide(color: C.hot, width: 2))
              : null,
        ),
        padding: EdgeInsets.fromLTRB(waiting ? 9 : 11, 10, 11, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              // Rozet eşleşmeden bağımsız: marka fişte zaten yazıyor,
              // eksik olan hangi kanonik ürüne gittiği. Dikkat isteyen
              // satırı şerit anlatıyor, rozet değil.
              child: BrandChip(
                _monogram(line),
                known: _monogram(line) != '?',
                size: 21,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.canonical ?? line.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: line.canonical == null ? C.muted : C.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(_hint(line), style: _hintStyle(line)),
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

  /// Marka rozetindeki harfler. Eşleşmiş satırda kanonik addan, henüz
  /// eşleşmemişte fişteki açılmış addan.
  static String _monogram(ReceiptLine line) {
    final source = line.canonical ?? line.displayName;
    final letters = source.replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü]'), '');
    if (letters.isEmpty) return '?';
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Adın altındaki tek satır: satırın neden dikkat istediği ya da istemediği.
  static String _hint(ReceiptLine line) {
    if (line.isExcluded) return 'endeks dışı';
    if (line.needsMatch) return 'eşleşme bekliyor';
    return line.rawLine;
  }

  static TextStyle _hintStyle(ReceiptLine line) =>
      line.needsMatch ? T.label.copyWith(color: C.hot) : T.raw;
}
