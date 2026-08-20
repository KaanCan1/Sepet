import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// 02 — Fiş okuma. Projenin kalbi buradaki "eşleşme?" etiketi: normalizasyon
/// emin olamadığı satırı kullanıcıya soruyor, böylece her satır için LLM
/// çağırmak gerekmiyor.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    fullscreenDialog: true,
    builder: (_) => const ScanScreen(),
  );

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final List<ReceiptLine> _lines = List.of(Mock.scanned);
  bool _reading = true;

  int get _pending => _lines.where((l) => l.needsMatch).length;

  @override
  void initState() {
    super.initState();
    // Cihaz üstü OCR'ın gecikmesini taklit et.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _reading = false);
    });
  }

  Future<void> _resolve(int i) async {
    final line = _lines[i];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0x00000000),
      barrierColor: const Color(0x3316181A),
      builder: (_) => _MatchSheet(line: line),
    );
    if (picked != null && mounted) {
      setState(() => _lines[i] = line.confirmedAs(picked));
    }
  }

  void _commit() {
    // pop() State'i söküyor; messenger referansını önceden al.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            '${_lines.length} satır sepete eklendi',
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_reading && _pending == 0;

    return ScreenFrame(
      title: 'Fişi okut',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.close, size: 17, color: C.muted, stroke: 1.6),
        ),
      ),
      footer: PrimaryButton(
        label: _reading
            ? 'Okunuyor…'
            : (_pending > 0
                  ? 'Önce $_pending eşleşmeyi onayla'
                  : 'Sepete ekle'),
        dark: true,
        onTap: ready ? _commit : null,
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 4),
              _Viewfinder(reading: _reading),
              const SizedBox(height: 14),
              Lbl(
                _reading
                    ? 'FİŞ OKUNUYOR…'
                    : '${_lines.length} SATIR OKUNDU'
                          '${_pending > 0 ? ' · $_pending EŞLEŞME ONAYI BEKLİYOR' : ' · HEPSİ EŞLEŞTİ'}',
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _reading ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                child: PaperCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        if (i > 0) const Hairline(),
                        _ParsedRow(
                          line: _lines[i],
                          onTap: _lines[i].needsMatch
                              ? () => _resolve(i)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_reading && _pending > 0)
                const Text(
                  'İşaretli satırlarda hangi kanonik ürüne denk geldiğinden '
                  'emin olunamadı. Onayladığın eşleşme kaydedilir; aynı fiş '
                  'formatı bir daha sorulmaz.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: C.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kamera görüntüsü + köşe kılavuzları. Demo'da fişin kendisi kâğıt olarak duruyor.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.reading});
  final bool reading;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void didUpdateWidget(_Viewfinder old) {
    super.didUpdateWidget(old);
    // Okuma bitince tarama çizgisini durdur — sonsuz kare planlamasın.
    if (!widget.reading && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 196,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEDE8),
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Fiş kâğıdı
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -.026,
                  child: Container(
                    width: 138,
                    padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
                    color: C.card,
                    child: const Text(
                      Mock.slipText,
                      style: TextStyle(
                        fontFamily: F.mono,
                        fontFamilyFallback: F.monoFallback,
                        fontSize: 6.8,
                        height: 1.72,
                        color: Color(0xFF9C9A94),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Tarama çizgisi
            if (widget.reading)
              AnimatedBuilder(
                animation: _c,
                builder: (_, _) => Positioned(
                  top: 196 * _c.value,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x0016181A),
                          Color(0x8016181A),
                          Color(0x0016181A),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const _Corners(),
          ],
        ),
      ),
    );
  }
}

class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: CustomPaint(size: Size.infinite, painter: _CornerPainter()),
  );
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = C.ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const l = 15.0;
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0)
      ..moveTo(s.width - l, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, l)
      ..moveTo(0, s.height - l)
      ..lineTo(0, s.height)
      ..lineTo(l, s.height)
      ..moveTo(s.width - l, s.height)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width, s.height - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// .pr — kanonik ad üstte, fişteki ham satır altta, tutar sağda.
class _ParsedRow extends StatelessWidget {
  const _ParsedRow({required this.line, this.onTap});

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
                        line.canonical,
                        style: const TextStyle(fontSize: 11, color: C.ink),
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

/// Eşleşme sorusu — buzlu cam alt sayfa.
class _MatchSheet extends StatelessWidget {
  const _MatchSheet({required this.line});
  final ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: GlassBar(
        borderSide: GlassEdge.none,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.muted.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Lbl('FİŞTEKİ SATIR'),
              const SizedBox(height: 5),
              Text(line.rawLine, style: T.num12),
              const SizedBox(height: 16),
              const Lbl('HANGİ ÜRÜN?'),
              const SizedBox(height: 8),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < line.candidates.length; i++) ...[
                      if (i > 0) const Hairline(),
                      Pressable(
                        scale: .99,
                        onTap: () =>
                            Navigator.of(context).pop(line.candidates[i]),
                        child: Container(
                          color: C.card,
                          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.candidates[i],
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: C.ink,
                                  ),
                                ),
                              ),
                              if (i == 0)
                                const Lbl('ÖNERİLEN')
                              else
                                const LineIcon(
                                  Glyph.chevron,
                                  size: 13,
                                  color: C.muted,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Seçimin bu markete ait fiş formatı için kaydedilir.',
                style: TextStyle(fontSize: 11, color: C.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
