import 'package:flutter/cupertino.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// Kaydedilmiş bir fişin satır kırılımı — 02'deki listenin salt-okunur hâli.
class ReceiptDetailScreen extends StatelessWidget {
  const ReceiptDetailScreen({super.key, required this.receipt});

  final Receipt receipt;

  static Route<void> route(Receipt r) =>
      CupertinoPageRoute(builder: (_) => ReceiptDetailScreen(receipt: r));

  @override
  Widget build(BuildContext context) {
    // Demo: her fiş aynı satır kırılımını gösteriyor.
    final lines = receipt.lines.isEmpty
        ? Mock.scanned.map((l) => l.confirmedAs(l.canonical)).toList()
        : receipt.lines;

    return ScreenFrame(
      title: receipt.market,
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.back, size: 17, color: C.ink, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 4),
              Lbl('${Fmt.dayMonth(receipt.date)} ${receipt.date.year} · '
                  '${receipt.itemCount} ÜRÜN'),
              const SizedBox(height: 4),
              Text(receipt.heading, style: T.display),
              const SizedBox(height: 12),
              PaperCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Fiş toplamı',
                        style: TextStyle(fontSize: 11.5, color: C.muted),
                      ),
                    ),
                    Text(Fmt.money(receipt.total), style: T.num12),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Lbl('EŞLEŞEN SATIRLAR'),
              const SizedBox(height: 8),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0) const Hairline(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lines[i].canonical,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: C.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(lines[i].rawLine, style: T.raw),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(Fmt.money(lines[i].amount), style: T.num11),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
