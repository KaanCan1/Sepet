import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import 'index_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'receipts_screen.dart';
import 'match_queue_screen.dart';

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
  int _tab = 0;

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
          Pressable(
            key: const Key('scan-button'),
            onTap: () => Navigator.of(context).push(MatchQueueScreen.route()),
            child: GlassSurface(
              radius: kTabCapsuleHeight / 2,
              child: SizedBox(
                width: kTabCapsuleHeight,
                height: kTabCapsuleHeight,
                child: const Center(
                  child: LineIcon(
                    Glyph.camera,
                    size: 22,
                    color: C.ink,
                    stroke: 1.5,
                  ),
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
