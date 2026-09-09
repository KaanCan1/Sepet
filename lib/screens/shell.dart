import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notifications.dart';
import '../theme/tokens.dart';
import '../state/app_data.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/motion.dart';
import 'index_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'receipts_screen.dart';
import 'capture_screen.dart';
import 'monthly_card_screen.dart';

/// Yüzen kapsülün yüksekliği ve alt boşluğu — içerik bunun altından akıyor.
const kTabCapsuleHeight = 58.0;
const kTabBarHeight = kTabCapsuleHeight + 18;
const kTopBarHeight = 44.0;

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  /// Sekme konumu: 0 ilk sekme, 3 sonuncu, aradaki her ondalık geçişin
  /// kendisi.
  ///
  /// Bu sayı ARTIK KABUĞUN, sekme çubuğunun değil. Sebebi tek: hapı ve
  /// altındaki ekranı aynı sayı sürsün. Konum çubuğun içinde kalırken hap
  /// parmakla akıyor ama gövde sert kesiyordu — hareketin yarısı yapılmış
  /// oluyordu. İkisinin ortak atası burası, paylaşılan durumun yeri de
  /// burası.
  ///
  /// `ValueNotifier`, `setState` değil: sürükleme sırasında saniyede altmış
  /// kez bütün kabuğu yeniden kurmanın anlamı yok, yalnızca konumu
  /// dinleyen iki küçük ağaç yeniden kuruluyor.
  final _konum = ValueNotifier(0.0);

  /// Bırakınca hapın hedefe yürümesi. Parmak ekrandayken çalışmıyor —
  /// o sırada konumu doğrudan parmak yazıyor.
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<double>? _yerlesme;

  /// Parmak ekranda mı. Bırakmayı bir kez işlemek için.
  bool _suruklemede = false;

  StreamSubscription<void>? _cardTaps;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final y = _yerlesme;
      if (y != null) _konum.value = y.value;
    });

    // Sekme cubit'lerinin ilk yüklemesi. Kabuk yalnızca oturum açıkken var,
    // dolayısıyla burada çağırmak "giriş yapıldı" demekle aynı şey; cubit'ler
    // kurulurken yüklenselerdi jeton gelmeden istek atıp 401 alırlardı.
    refreshUserData(context);

    // Aylık kart bildirimi. Aynı gerekçe: plan yalnızca oturum açıkken
    // tazeleniyor, çünkü kartın arkasındaki veri oturuma bağlı.
    final reminder = context.read<MonthlyReminder>();
    reminder.restore();
    // Uygulama bildirime dokunularak açıldıysa kart doğrudan açılıyor.
    if (reminder.takePendingCard()) _openCard();
    _cardTaps = reminder.cardTaps.listen((_) => _openCard());
  }

  /// Kart tam ekran bir sayfa; üst üste iki tane açılmasın.
  void _openCard() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cardOpen) return;
      _cardOpen = true;
      nav.push(MonthlyCardScreen.route()).whenComplete(() => _cardOpen = false);
    });
  }

  bool _cardOpen = false;

  @override
  void dispose() {
    _cardTaps?.cancel();
    _c.dispose();
    _konum.dispose();
    super.dispose();
  }

  /// Hapı [hedef] sekmeye yürütüyor.
  void _yerlestir(double hedef) {
    if (M.off(context)) {
      _konum.value = hedef;
      return;
    }
    _yerlesme = Tween(
      begin: _konum.value,
      end: hedef,
    ).animate(CurvedAnimation(parent: _c, curve: M.curve));
    _c.forward(from: 0);
  }

  void _dokun(int i) {
    _c.stop();
    _yerlestir(i.toDouble());
  }

  void _surukle(double birim) {
    final onceki = _konum.value.round();
    _c.stop();
    _suruklemede = true;
    _konum.value = birim;
    // Sınırı geçerken kısa bir dokunuş. Sürüklerken göz haptadır, hangi
    // sekmeye girildiği ekrandan değil parmaktan anlaşılıyor.
    if (birim.round() != onceki) HapticFeedback.selectionClick();
  }

  void _birak() {
    if (!_suruklemede) return;
    _suruklemede = false;
    _yerlestir(_konum.value.round().toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.paper,
      // Kapsül içeriğin üstünde yüzüyor: gövde ekranın tamamını kaplıyor.
      extendBody: true,
      body: Stack(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _konum,
            builder: (context, konum, _) =>
                _Govde(konum: konum, hareket: !M.off(context)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingTabBar(
              konum: _konum,
              onTap: _dokun,
              onSurukle: _surukle,
              onBirak: _birak,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekmelerin gövdesi — konumla birlikte kayan ve çözülen ekranlar.
///
/// Dört ekran da ağaçta kalıyor. Sebebi kaydırma konumları ve bir kez oynayan
/// giriş animasyonları: sekmeden çıkıp dönünce liste başa sarmasın, satırlar
/// yeniden basılmasın. Ama yalnızca ikisi ÇİZİLİYOR — konumun iki yanındaki
/// komşular; kalanlar [Offstage] ile hem boyamanın hem yerleşimin dışında.
class _Govde extends StatelessWidget {
  const _Govde({required this.konum, required this.hareket});

  /// Kabuğun sekme konumu. Tam sayı yerleşmiş sekme, ondalık geçiş.
  final double konum;

  /// "Hareketi Azalt" kapalıysa true. Kapalıyken kayma da çözülme de yok:
  /// yerleşmiş sekme doğrudan görünüyor.
  final bool hareket;

  static const _ekranlar = [
    IndexScreen(),
    ReceiptsScreen(),
    ProductsScreen(),
    ProfileScreen(),
  ];

  /// Bir sekmelik kaymanın ekran genişliğine oranı.
  ///
  /// 1 değil, çünkü çubuk üzerinde üç sekmelik sürükleme parmağın altında
  /// birkaç santim; gövde birebir izleseydi o birkaç santimde üç ekran boyu
  /// yol alır, geçiş değil savrulma olurdu. Bu oranda hareket parmağı
  /// İŞARET ediyor, taklit etmiyor.
  static const _kayma = .32;

  /// Çözülmenin eğrisi. Konum doğrusal — parmağı birebir izliyor — ama
  /// opaklık değil.
  ///
  /// Sebebi ölçüldü: iki ekran da yoğun metin, doğrusal çözülmede orta
  /// bölgede uzun süre yarı yarıya üst üste biniyorlar ve ortaya iki
  /// sayfanın birbirine karıştığı okunmaz bir kare çıkıyor. Bu eğri o
  /// bölgeyi sıkıştırıyor: yolun onda dördünde gelen ekran hâlâ %13'te,
  /// onda altısında %87'de. Karışma var ama göz onu yakalamıyor.
  static const _cozulme = Curves.easeInOutQuart;

  @override
  Widget build(BuildContext context) {
    // Alttaki katman tam opak, üstteki çözülerek geliyor. Sıra hep artan
    // olmak zorunda: Stack çocuklarını sırayla boyuyor ve dört ekranın
    // tipleri farklı, yer değiştirselerdi eşleşme tutmaz, ekranlar
    // durumlarıyla birlikte yeniden kurulurdu.
    final int alt = hareket
        ? konum.floor().clamp(0, _ekranlar.length - 1).toInt()
        : konum.round();
    final double t = hareket ? konum - alt : 0;

    return LayoutBuilder(
      builder: (context, kutu) => Stack(
        children: [
          for (final (i, ekran) in _ekranlar.indexed)
            Positioned.fill(
              child: Offstage(
                // Üstteki katman t sıfırken hiç görünmüyor; yerleşmiş
                // sekmede tek katman çiziliyor.
                offstage: i != alt && !(i == alt + 1 && t > 0),
                child: Transform.translate(
                  offset: Offset(
                    hareket ? (i - konum) * kutu.maxWidth * _kayma : 0,
                    0,
                  ),
                  child: Opacity(
                    opacity: i == alt ? 1 : _cozulme.transform(t),
                    child: ekran,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Yüzen cam kapsül + ayrık daire eylem düğmesi.
///
/// Seçili sekmenin zemini artık her sekmenin kendi kutusu değil, kapsül
/// boyunca kayan TEK bir hap. Sebebi hareketin kendisi: sekmeye basılı
/// tutup yana sürüklenince seçim parmakla birlikte akıyor, iOS'un kendi
/// sekme çubuğundaki gibi. Ayrı ayrı kutular olsaydı geçiş yapılamazdı —
/// biri sönerken diğeri yanardı, arada bir şey hareket etmezdi.
///
/// Konumu artık kendi tutmuyor: aynı sayı gövdeyi de sürdüğü için yeri
/// ikisinin ortak atası olan [Shell]. Burada kalan iş, yatay konumu sekme
/// birimine çevirip yukarı bildirmek.
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.konum,
    required this.onTap,
    required this.onSurukle,
    required this.onBirak,
  });

  final ValueListenable<double> konum;
  final ValueChanged<int> onTap;

  /// Parmağın o anki konumu, sekme birimi cinsinden — ondalık olabiliyor.
  final ValueChanged<double> onSurukle;
  final VoidCallback onBirak;

  static const items = [
    (Glyph.home, 'Endeks'),
    (Glyph.doc, 'Fişler'),
    (Glyph.chart, 'Ürünler'),
    (Glyph.person, 'Profil'),
  ];

  /// Yatay konumu sekme birimine çeviriyor.
  double _birim(double dx, double genislik) =>
      (dx / genislik - .5).clamp(0, items.length - 1);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final c = context.c;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, inset > 0 ? inset : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GlassSurface(
              radius: kTabCapsuleHeight / 2,
              child: SizedBox(
                height: kTabCapsuleHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: LayoutBuilder(
                    builder: (context, kutu) {
                      final genislik = kutu.maxWidth / items.length;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) =>
                            onTap(_birim(d.localPosition.dx, genislik).round()),
                        // Sürükleme basılı tutmayı beklemiyor: iOS'ta da
                        // parmak yana kaydığı an hap takip ediyor.
                        onHorizontalDragStart: (d) =>
                            onSurukle(_birim(d.localPosition.dx, genislik)),
                        onHorizontalDragUpdate: (d) =>
                            onSurukle(_birim(d.localPosition.dx, genislik)),
                        onHorizontalDragEnd: (_) => onBirak(),
                        onHorizontalDragCancel: onBirak,
                        child: ValueListenableBuilder<double>(
                          valueListenable: konum,
                          builder: (context, k, _) => Stack(
                            children: [
                              Positioned(
                                left: k * genislik + 2,
                                top: _hapPayi,
                                bottom: _hapPayi,
                                width: genislik - 4,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.ink.withValues(alpha: .07),
                                    borderRadius: BorderRadius.circular(
                                      _hapYaricapi,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (final (i, item) in items.indexed)
                                    Expanded(
                                      child: _Tab(
                                        key: Key('tab-$i'),
                                        glyph: item.$1,
                                        label: item.$2,
                                        // Hap yaklaştıkça sekme koyulaşıyor:
                                        // geçiş sırasında iki sekme birden
                                        // yarı yanık oluyor ve hareket
                                        // okunur hâle geliyor.
                                        yakinlik: (1 - (i - k).abs()).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Ayrık düğme: taramanın her ekrandan tek dokunuşla açılması için.
          //
          // Camdan mürekkebe çevrildi. Uygulamanın yaptığı tek iş fiş
          // okumak, ama düğme sekmelerle aynı ağırlıkta durunca beşinci bir
          // sekme gibi okunuyordu; ilk kez açan kullanıcı nereden
          // başlayacağını göremiyordu. Dolu daire onu tek birincil eylem
          // yapıyor — sayfadaki tek koyu yüzey.
          Pressable(
            key: const Key('scan-button'),
            onTap: () async {
              final added = await Navigator.of(context)
                  .push(CaptureScreen.route());
              if (added == true && context.mounted) refreshUserData(context);
            },
            child: Container(
              width: kTabCapsuleHeight,
              height: kTabCapsuleHeight,
              decoration: BoxDecoration(
                color: c.ink,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.ink.withValues(alpha: .22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: LineIcon(
                  Glyph.camera,
                  size: 23,
                  color: c.card,
                  stroke: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hapın kapsül kenarına bıraktığı dikey pay.
const _hapPayi = 5.0;

/// Hapın yarıçapı: dıştaki kapsülün yarıçapı eksi içeri payı.
///
/// İki eğri böyle EŞ MERKEZLİ oluyor — hap kapsülün içinde onunla aynı
/// dili konuşuyor. Sabit 16 idi ve kapsül 29'ken köşeli bir dikdörtgen
/// gibi duruyordu, iki ayrı şekil ailesi yan yanaydı.
///
/// 58/2 - 5 = 24, yani hap tam bir stadyum: kendi yüksekliğinin (58 - 2x5)
/// yarısı. Yuvarlaklık tesadüf değil, geometrinin sonucu.
const _hapYaricapi = kTabCapsuleHeight / 2 - _hapPayi;

/// Tek sekme: simge + etiket. Zemini yok — seçili hap üstteki katmanda,
/// kapsül boyunca kayan tek bir parça.
class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.glyph,
    required this.label,
    required this.yakinlik,
  });

  final Glyph glyph;
  final String label;

  /// 0 uzak, 1 hapın tam altında. Renk ve kalınlık buradan türüyor, böylece
  /// sürükleme sırasında ara değerler de geçerli bir görünüm veriyor.
  final double yakinlik;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = Color.lerp(c.muted, c.ink, yakinlik)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LineIcon(glyph, size: 20, color: color, stroke: 1.5),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 9.5,
              height: 1,
              letterSpacing: -.1,
              fontWeight: FontWeight.lerp(
                FontWeight.w400,
                FontWeight.w600,
                yakinlik,
              ),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
