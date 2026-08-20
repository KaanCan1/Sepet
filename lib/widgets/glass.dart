import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';

/// Üst bar ve alt sayfa kromu — düz bulanıklık, kırılma yok.
///
/// Tam genişlikte kırılmalı cam denendi ve kâğıt zeminde gri bir levha gibi
/// durdu: yarıçapı sıfır bir yüzeyin kıracak kenarı yok, geriye sadece
/// kalınlığın koyulaştırması kalıyor. Cam gösterisi yüzen parçalara bırakıldı.
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
    final border = BorderSide(color: C.line.withValues(alpha: .5), width: .5);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: C.paper.withValues(alpha: .55),
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

/// Yüzen krom parçaları — kapsül tab bar ve ayrık daire düğme.
///
/// Elle yazdığım gradient/gölge taklidi kalktı: şekli `LiquidShape` olarak
/// verip kırılmayı paketin shader'ına bırakıyoruz. Yarıçap yüksekliğin yarısına
/// eşitse süperelips yerine gerçek daire/kapsül isteniyor demektir.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.radius,
    this.circle = false,
  });

  final Widget child;
  final double radius;

  /// Daire düğme — kırılma kenarda her yönde eşit olsun diye ayrı şekil.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      shape: circle
          ? const LiquidOval()
          : LiquidRoundedSuperellipse(borderRadius: radius),
      settings: GlassSettings.floating,
      // Yüzen parça kendi katmanında: altındaki içerik kaydıkça kırılma da
      // yeniden hesaplansın.
      useOwnLayer: true,
      allowElevation: false,
      child: child,
    );
  }
}

/// Cam ayarları tek yerde. Kâğıt zemin (#F7F6F3) neredeyse düz olduğu için
/// kırılmanın oynayacağı çok doku yok — iş speküler kenara ve ince bir
/// renk sapmasına bırakılıyor, bulanıklık ölçülü tutuluyor.
abstract final class GlassSettings {
  /// Yüzen kapsül / daire düğme.
  static const floating = LiquidGlassSettings(
    // Neredeyse renksiz: zemin kâğıt olduğu için her tint gri okuyor.
    glassColor: Color(0x14FFFFFF),
    visibility: .12,
    thickness: 7,
    blur: 4,
    chromaticAberration: .02,
    lightIntensity: 1.05,
    ambientStrength: .1,
    ambientRim: .5,
    fresnelStrength: .85,
    refractiveIndex: 1.3,
    saturation: 1,
    specularSharpness: GlassSpecularSharpness.sharp,
    // Kenar emilimi griliğin asıl kaynağıydı — neredeyse kapalı.
    edgeAbsorption: .04,
    whitenStrength: .1,
    shadowElevation: .5,
  );

  /// Üst bar ve alt sayfa — içeriğin okunması gerektiği için daha sakin.
  static const bar = LiquidGlassSettings(
    glassColor: C.paper,
    visibility: .46,
    thickness: 9,
    blur: 14,
    chromaticAberration: .02,
    lightIntensity: .9,
    ambientStrength: .32,
    fresnelStrength: .38,
    refractiveIndex: 1.34,
    saturation: 1,
    specularSharpness: GlassSpecularSharpness.soft,
    edgeAbsorption: .22,
  );

  /// Uygulama genelindeki varsayılan — tema katmanı ayrı bir tip istiyor.
  static const theme = GlassThemeSettings(
    glassColor: C.paper,
    visibility: .34,
    thickness: 14,
    blur: 8,
    chromaticAberration: .035,
    lightIntensity: 1.15,
    ambientStrength: .38,
    fresnelStrength: .55,
    refractiveIndex: 1.42,
    saturation: 1.02,
    specularSharpness: GlassSpecularSharpness.sharp,
    edgeAbsorption: .3,
  );
}
