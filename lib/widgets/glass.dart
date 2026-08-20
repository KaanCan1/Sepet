import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Apple'ın buzlu cam kromu: içerik altından geçerken bulanıklaşır,
/// kenarda saç teli kadar bir çizgi kalır. Renk yine kâğıt.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.borderSide = GlassEdge.bottom,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final GlassEdge borderSide;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: C.line.withValues(alpha: .55), width: .5);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: C.paper.withValues(alpha: .62),
            border: Border(
              top: borderSide == GlassEdge.top ? border : BorderSide.none,
              bottom: borderSide == GlassEdge.bottom ? border : BorderSide.none,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum GlassEdge { top, bottom, none }

/// Fiş kâğıdı kartı — beyaz zemin, saç teli çerçeve, çok yumuşak gölge.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    this.radius = 10,
    this.borderColor = C.line,
    this.borderWidth = 1,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x0F16181A),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Basınca hafifçe küçülen dokunma katmanı — Apple'ın hissi.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? .72 : 1,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// iOS 26 "Liquid Glass" yüzeyi: arkasını bulanıklaştırır, üst kenarında
/// ışık toplar, altına yumuşak bir gölge bırakır. Yüzen kapsül ve
/// ayrık daire düğme bunun üstüne kuruluyor.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.radius,
    this.blur = 30,
    this.tint = .58,
  });

  final Widget child;
  final double radius;
  final double blur;

  /// Zeminin opaklığı — düştükçe altındaki içerik daha çok okunur.
  final double tint;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1416181A),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x0A16181A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              // Üstte ışık, altta hafif gölge — camın kalınlığı buradan okunuyor.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFFFFF).withValues(alpha: tint + .16),
                  C.paper.withValues(alpha: tint),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFFFFF).withValues(alpha: .55),
                width: .8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
