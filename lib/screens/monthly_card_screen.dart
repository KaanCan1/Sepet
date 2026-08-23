import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/fmt.dart';
import '../data/repository.dart';
import '../state/monthly_card_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'product_screen.dart';

/// 04 — Aylık kart. Ayın 3'ünde resmî veri çıkınca gelen bildirimin varış
/// noktası. Kartın alt kenarı fişin koparma çizgisi.
class MonthlyCardScreen extends StatefulWidget {
  const MonthlyCardScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    fullscreenDialog: true,
    builder: (context) => BlocProvider(
      create: (_) => MonthlyCardCubit(context.read<Repository>())..load(),
      child: const MonthlyCardScreen(),
    ),
  );

  @override
  State<MonthlyCardScreen> createState() => _MonthlyCardScreenState();
}

class _MonthlyCardScreenState extends State<MonthlyCardScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<File?> _writeTemp() async {
    final bytes = await _capture();
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sepet-${DateTime.now().month}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _share(double? changePct) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _writeTemp();
      if (file == null || !mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              '${Fmt.monthLong(DateTime.now())} ayında benim sepetim '
              '${Fmt.pct1(changePct ?? 0)} zamlandı. Kendi fişimden hesapladım.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await _writeTemp();
    if (file == null || !mounted) return;
    final size = await file.length();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            'Görsel kaydedildi · ${(size / 1024).round()} KB',
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final month = Fmt.monthLong(DateTime.now());

    return ScreenFrame(
      title: '$month özeti',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.close, size: 17, color: C.muted, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DataView<MonthlyCardCubit, MonthlyCard>(
            isEmpty: (d) => d.snapshot.isEmpty,
            empty: const EmptyState(
              title: 'Paylaşacak bir şey yok',
              body: 'Kart, endeks hesaplanabilir olduğunda hazırlanır.',
            ),
            builder: (context, data) {
              final MonthlyCard(:snapshot, :movers, :receipts) = data;
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    RepaintBoundary(
                      key: _cardKey,
                      child: _ShareCard(
                        month: month,
                        snapshot: snapshot,
                        receiptCount: receipts.length,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Görseli kaydet',
                            dark: false,
                            onTap: _save,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PrimaryButton(
                            label: _busy ? 'Hazırlanıyor…' : 'Paylaş',
                            onTap: _busy
                                ? null
                                : () => _share(snapshot.changePct),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Hairline(),
                    const SizedBox(height: 12),
                    // Başlık veriye uymalı: her şey ucuzladıysa "en çok
                    // zamlanan" demek yanlış olur.
                    Lbl(
                      movers.isNotEmpty && movers.first.pct > 0
                          ? 'BU AY EN ÇOK ZAMLANAN'
                          : 'BU AY EN ÇOK DEĞİŞEN',
                    ),
                    const SizedBox(height: 2),
                    if (movers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Bu ay iki kez gözlenmiş ürün yok — değişim ancak '
                          'aynı ürünü iki ayda da görünce ölçülebiliyor.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: C.muted,
                          ),
                        ),
                      ),
                    for (final m in movers.take(5))
                      Pressable(
                        onTap: () =>
                            Navigator.of(context)
                                .push(ProductScreen.route(m.productId)),
                        child: LedgerRow(
                          name: m.title,
                          amount: Fmt.signedPct1(m.pct),
                          amountColor: m.pct >= 0 ? C.hot : C.ref,
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

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.month,
    required this.snapshot,
    required this.receiptCount,
  });

  final String month;
  final IndexSnapshot snapshot;
  final int receiptCount;

  @override
  Widget build(BuildContext context) {
    final known = snapshot.official.where((s) => s.value != null).toList();

    return PaperCard(
      radius: 12,
      borderColor: C.ink,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$month ${DateTime.now().year} · '
            '${snapshot.windowMonths >= 12 ? '12 AYLIK' : '${snapshot.windowMonths} AYLIK'}',
            style: T.label.copyWith(fontSize: 9, letterSpacing: 1.26),
          ),
          const SizedBox(height: 10),
          BigNumber(Fmt.dec1(snapshot.changePct ?? 0), size: 52),
          const SizedBox(height: 2),
          const Lbl('BENİM SEPETİM'),
          const SizedBox(height: 8),
          Text(
            '$receiptCount fiş üzerinden hesaplandı.'
            '${known.isEmpty ? '' : ' Aynı dönemde '
                      '${known.map((s) => '${s.publisher} ${Fmt.pct1(s.value!)}').join(', ')} '
                      'açıkladı.'}',
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: C.muted),
          ),
          const SizedBox(height: 14),
          const TearEdge(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SEPET', style: T.label.copyWith(fontSize: 8.5)),
              Text('KENDİ FİŞİNDEN', style: T.label.copyWith(fontSize: 8.5)),
            ],
          ),
        ],
      ),
    );
  }
}
