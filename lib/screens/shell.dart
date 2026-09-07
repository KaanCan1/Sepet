import 'dart:async';

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

class _ShellState extends State<Shell> {
  /// Hangi sekmenin açık olduğu. Tek bir widget'ın içinde doğup ölen geçici
  /// durum — Bloc'a taşınacak bir şey değil, yeri burası.
  int _tab = 0;

  StreamSubscription<void>? _cardTaps;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.paper,
      // Kapsül içeriğin üstünde yüzüyor: gövde ekranın tamamını kaplıyor.
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [
              IndexScreen(),
              ReceiptsScreen(),
              ProductsScreen(),
              ProfileScreen(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingTabBar(
              index: _tab,
              onTap: (i) => setState(() => _tab = i),
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
class _FloatingTabBar extends StatefulWidget {
  const _FloatingTabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (Glyph.home, 'Endeks'),
    (Glyph.doc, 'Fişler'),
    (Glyph.chart, 'Ürünler'),
    (Glyph.person, 'Profil'),
  ];

  @override
  State<_FloatingTabBar> createState() => _FloatingTabBarState();
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

class _FloatingTabBarState extends State<_FloatingTabBar>
    with SingleTickerProviderStateMixin {
  /// Hapın yerleşmesi. Sürüklerken kullanılmıyor — parmak varken hap
  /// parmağın yerinde duruyor, animasyon yalnızca bırakınca devreye giriyor.
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late Animation<double> _yerlesme = AlwaysStoppedAnimation(
    widget.index.toDouble(),
  );

  /// Parmak ekrandayken hapın sekme birimi cinsinden konumu. null = sürükleme
  /// yok.
  double? _surukleme;

  /// Hapın o anki konumu: 0 ilk sekme, 3 sonuncu. Ondalık olabiliyor —
  /// aradaki her değer geçişin kendisi.
  double get _konum => _surukleme ?? _yerlesme.value;

  @override
  void didUpdateWidget(_FloatingTabBar eski) {
    super.didUpdateWidget(eski);
    // Sekme dışarıdan değiştiyse (dokunma ya da başka bir yol) hap oraya
    // yürüsün. Sürükleme sürerken karışmıyor.
    if (eski.index != widget.index && _surukleme == null) {
      _yerlestir(widget.index.toDouble());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _yerlestir(double hedef) {
    if (M.off(context)) {
      setState(() => _yerlesme = AlwaysStoppedAnimation(hedef));
      return;
    }
    _yerlesme = Tween(
      begin: _konum,
      end: hedef,
    ).animate(CurvedAnimation(parent: _c, curve: M.curve));
    _c.forward(from: 0);
  }

  /// Yatay konumu sekme birimine çeviriyor.
  double _birim(double dx, double genislik) =>
      (dx / genislik - .5).clamp(0, _FloatingTabBar.items.length - 1);

  void _surukle(double dx, double genislik) {
    final yeni = _birim(dx, genislik);
    final oncekiSekme = _konum.round();
    setState(() => _surukleme = yeni);
    final sekme = yeni.round();
    if (sekme != oncekiSekme) {
      // Sınırı geçerken kısa bir dokunuş. Sürüklerken göz haptadır, hangi
      // sekmeye girildiği ekrandan değil parmaktan anlaşılıyor.
      HapticFeedback.selectionClick();
      widget.onTap(sekme);
    }
  }

  void _birak() {
    if (_surukleme == null) return;
    final hedef = _surukleme!.round();
    setState(() => _surukleme = null);
    _yerlestir(hedef.toDouble());
    if (hedef != widget.index) widget.onTap(hedef);
  }

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
                      final genislik =
                          kutu.maxWidth / _FloatingTabBar.items.length;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => widget.onTap(
                          _birim(d.localPosition.dx, genislik).round(),
                        ),
                        // Sürükleme basılı tutmayı beklemiyor: iOS'ta da
                        // parmak yana kaydığı an hap takip ediyor.
                        onHorizontalDragStart: (d) =>
                            _surukle(d.localPosition.dx, genislik),
                        onHorizontalDragUpdate: (d) =>
                            _surukle(d.localPosition.dx, genislik),
                        onHorizontalDragEnd: (_) => _birak(),
                        onHorizontalDragCancel: _birak,
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) {
                            final konum = _konum;
                            return Stack(
                              children: [
                                Positioned(
                                  left: konum * genislik + 2,
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
                                    for (final (i, item)
                                        in _FloatingTabBar.items.indexed)
                                      Expanded(
                                        child: _Tab(
                                          key: Key('tab-$i'),
                                          glyph: item.$1,
                                          label: item.$2,
                                          // Hap yaklaştıkça sekme
                                          // koyulaşıyor: geçiş sırasında iki
                                          // sekme birden yarı yanık oluyor
                                          // ve hareket okunur hâle geliyor.
                                          yakinlik: (1 - (i - konum).abs())
                                              .clamp(0.0, 1.0),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
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
