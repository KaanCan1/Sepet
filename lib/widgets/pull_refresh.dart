import 'package:flutter/cupertino.dart';

import '../theme/tokens.dart';

/// Aşağı çekince görünen yenileme göstergesi.
///
/// Hazır çarkı kullanmıyoruz: uygulamanın dili kâğıt fiş — monospace
/// etiketler, ince çizgiler, mürekkep. Ortadaki dönen mavi çark başka bir
/// uygulamadan ödünç alınmış gibi duruyordu.
///
/// Buradaki hareket yazarkasanın kendi hareketi: çekildikçe ortadan dışa
/// doğru bir kesme çizgisi açılıyor, bırakma eşiğine gelince mürekkebe
/// dönüyor, yenilenirken de çizginin üstünde bir baskı kafası gidip
/// geliyor.
class PaperRefreshIndicator extends StatefulWidget {
  const PaperRefreshIndicator({
    super.key,
    required this.mode,
    required this.pulled,
    required this.trigger,
  });

  final RefreshIndicatorMode mode;
  final double pulled;
  final double trigger;

  @override
  State<PaperRefreshIndicator> createState() => _PaperRefreshIndicatorState();
}

class _PaperRefreshIndicatorState extends State<PaperRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _head = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PaperRefreshIndicator old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _sync();
  }

  /// Baskı kafası yalnızca gerçekten beklenirken gidip geliyor. Sürekli
  /// dönen bir gösterge "bir şey oluyor" demeyi bırakıp süs olur.
  void _sync() {
    final calisiyor =
        widget.mode == RefreshIndicatorMode.refresh ||
        widget.mode == RefreshIndicatorMode.armed;
    if (calisiyor && !_head.isAnimating) {
      _head.repeat();
    } else if (!calisiyor && _head.isAnimating) {
      _head.stop();
      _head.value = 0;
    }
  }

  @override
  void dispose() {
    _head.dispose();
    super.dispose();
  }

  String get _label => switch (widget.mode) {
    RefreshIndicatorMode.armed => 'BIRAK',
    RefreshIndicatorMode.refresh => 'YENİLENİYOR',
    RefreshIndicatorMode.done => 'GÜNCEL',
    _ => 'ÇEK',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.mode == RefreshIndicatorMode.inactive) {
      return const SizedBox.shrink();
    }

    final t = widget.trigger <= 0
        ? 0.0
        : (widget.pulled / widget.trigger).clamp(0.0, 1.0);
    final calisiyor =
        widget.mode == RefreshIndicatorMode.refresh ||
        widget.mode == RefreshIndicatorMode.armed;

    // Gösterge kutusu toplanırken içerikten kısa kalabiliyor ve sabit
    // yükseklikli bir Column orada taşıyor. Kırpmak doğru davranış:
    // toplanan bir göstergenin son karelerinde yazının kesilmesi
    // beklenen şey, kırmızı taşma şeridi değil.
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        minHeight: 0,
        maxHeight: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _head,
              builder: (context, _) => CustomPaint(
                size: const Size(190, 12),
                painter: _TearLinePainter(
                  acilma: calisiyor ? 1 : t,
                  kafa: calisiyor ? _head.value : null,
                ),
              ),
            ),
            const SizedBox(height: 7),
            // Etiket çekme ilerledikçe beliriyor; sıfırdan görünür olması
            // ekranın üstünde sürekli duran bir yazı gibi okunuyordu.
            Opacity(
              opacity: calisiyor ? 1 : (t * 1.4).clamp(0.0, 1.0),
              child: Text(_label, style: T.label.copyWith(fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ortadan dışa açılan kesme çizgisi ve üstünde gidip gelen baskı kafası.
class _TearLinePainter extends CustomPainter {
  const _TearLinePainter({required this.acilma, required this.kafa});

  /// 0..1 — çizginin ne kadarı açıldı.
  final double acilma;

  /// 0..1 — baskı kafasının konumu. Yenilenmiyorsa null.
  final double? kafa;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final orta = size.width / 2;
    final yari = (size.width / 2) * acilma;
    if (yari <= 0) return;

    // Kesik çizgi: fişin koparma yeri. Eşiğe gelince mürekkebe dönüyor.
    final kalem = Paint()
      ..color = Color.lerp(C.line, C.ink, acilma)!
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const bosluk = 5.0;
    const cizgi = 4.0;
    for (var x = orta - yari; x < orta + yari; x += cizgi + bosluk) {
      final bitis = (x + cizgi).clamp(orta - yari, orta + yari);
      canvas.drawLine(Offset(x, y), Offset(bitis, y), kalem);
    }

    final k = kafa;
    if (k == null) return;

    // Kafa bir uçtan diğerine gidip DÖNÜYOR; tek yönde akan bir nokta
    // "yükleniyor"dan çok "ilerliyor" diyor ve ilerleme bilgimiz yok.
    final gidis = k < .5 ? k * 2 : (1 - k) * 2;
    final egri = Curves.easeInOut.transform(gidis);
    final x = (orta - yari) + (yari * 2) * egri;
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = C.hot);
  }

  @override
  bool shouldRepaint(_TearLinePainter old) =>
      old.acilma != acilma || old.kafa != kafa;
}
