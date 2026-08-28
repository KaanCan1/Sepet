import 'dart:async';

import 'package:flutter/widgets.dart';

/// Hareketin tek kaynağı — renk ve tipografi gibi hareket de belirteçle.
///
/// **Metafor kâğıt fiş.** Yazıcıdan çıkan bir fiş satır satır belirir, hepsi
/// birden değil. Bu yüzden içerik yukarıdan kaymıyor, aşağıdan **basılıyor**:
/// az bir yükselme (bir satır yüksekliğinden küçük) ve solma. Ekrana giren
/// şey bir kâğıt, bir kart destesi değil.
///
/// Süreler kısa tutuldu. Hareket ekranın kendisini göstermek için değil,
/// içeriğin hangi sırayla okunacağını söylemek için var — bittiğinde
/// fark edilmemeli.
abstract final class M {
  /// Tek bir bloğun belirme süresi.
  static const enter = Duration(milliseconds: 380);

  /// Ardışık iki blok arasındaki gecikme.
  static const stagger = Duration(milliseconds: 45);

  /// Grafik çizgisinin soldan sağa çizilme süresi. Diğerlerinden uzun:
  /// burada hareketin kendisi veri anlatıyor — zaman ekseni.
  static const draw = Duration(milliseconds: 720);

  static const curve = Curves.easeOutCubic;

  /// Yükselme mesafesi. 10 piksel: gözün yakaladığı ama "kaydı" demediği
  /// aralık.
  static const rise = 10.0;

  /// Kademeli girişte kaçıncı bloktan sonra gecikme artmıyor. Onuncu satır
  /// yarım saniye beklemesin.
  static const maxStep = 8;

  /// İşletim sisteminde "Hareketi Azalt" açıksa hiçbir şey oynamıyor.
  ///
  /// Bu bir incelik değil, erişilebilirlik gereği: vestibüler rahatsızlığı
  /// olan kullanıcı için kayan içerik baş dönmesi sebebi.
  static bool off(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// Kâğıt fiş gibi basılan blok: aşağıdan yükselerek beliriyor.
///
/// [step] okuma sırası. Aynı ekrandaki bloklar 0'dan başlayarak numaralanır;
/// gecikme buradan hesaplanıyor, böylece sıra tek bir yerde — ekranın
/// kendisinde — okunuyor.
///
/// Animasyon **yalnızca bir kez** oynuyor. Widget ağaçta kaldığı sürece
/// durum da kalıyor, yani aşağı çekip tazelemek her şeyi yeniden
/// zıplatmıyor; sessiz tazelemede eldeki içerik yerinde duruyor.
class Printed extends StatefulWidget {
  const Printed({super.key, required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  State<Printed> createState() => _PrintedState();
}

class _PrintedState extends State<Printed> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: M.enter);
  late final _t = CurvedAnimation(parent: _c, curve: M.curve);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(M.stagger * widget.step.clamp(0, M.maxStep), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (M.off(context)) return widget.child;

    return AnimatedBuilder(
      animation: _t,
      // Çocuk bir kez kuruluyor; her karede yeniden inşa edilmiyor.
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, M.rise * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Kademeli girişi elle numaralamadan uygulamanın kısa yolu: listedeki her
/// çocuk sırayla basılıyor.
///
/// [from] birden başlıyorsa veriliyor — üstünde elle numaralanmış bloklar
/// varsa sıra kopmasın.
List<Widget> printed(List<Widget> children, {int from = 0}) => [
  for (var i = 0; i < children.length; i++)
    Printed(step: from + i, child: children[i]),
];
