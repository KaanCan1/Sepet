import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notifications.dart';
import '../theme/tokens.dart';
import '../state/app_data.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
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
      backgroundColor: C.paper,
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
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Glyph.home, 'Endeks'),
    (Glyph.doc, 'Fişler'),
    (Glyph.chart, 'Ürünler'),
    (Glyph.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;

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
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: _Tab(
                            key: Key('tab-$i'),
                            glyph: _items[i].$1,
                            label: _items[i].$2,
                            selected: index == i,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
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
                color: C.ink,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: C.ink.withValues(alpha: .22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: LineIcon(
                  Glyph.camera,
                  size: 23,
                  color: C.card,
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

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Glyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? C.ink : C.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? C.ink.withValues(alpha: .07)
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(16),
          ),
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
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
