import 'package:flutter/material.dart';

import '../screens/shell.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// Her ekranın ortak kabuğu: içerik akar, üstteki bar camdan onu bulanıklaştırır.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    required this.slivers,
    this.footer,
    this.reserveTabBar = false,
    this.showTopBar = true,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> slivers;

  /// Alta sabitlenen buzlu cam eylem çubuğu ("Sepete ekle" gibi).
  final Widget? footer;

  final bool reserveTabBar;
  final bool showTopBar;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final bottomReserve = (reserveTabBar ? kTabBarHeight + pad.bottom : 0.0);

    return Scaffold(
      backgroundColor: C.paper,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: pad.top + (showTopBar ? kTopBarHeight : 0) + 4,
                ),
              ),
              ...slivers,
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomReserve + 28),
              ),
            ],
          ),
          if (showTopBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassBar(
                padding: EdgeInsets.only(top: pad.top),
                child: SizedBox(
                  height: kTopBarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        SizedBox(width: 32, child: leading),
                        Expanded(
                          child: Center(
                            child: Text(
                              title ?? '',
                              style: T.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: trailing,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (footer != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassBar(
                borderSide: GlassEdge.top,
                padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + pad.bottom),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Ekran içi yatay ölçü — taslakta 18px.
const kGutter = EdgeInsets.symmetric(horizontal: 18);

/// Koyu, tam genişlik eylem düğmesi (.cta).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.dark = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: !enabled ? C.card : (dark ? C.ink : C.card),
          border:
              Border.all(color: !enabled ? C.line : (dark ? C.ink : C.line)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: !enabled ? C.muted : (dark ? C.card : C.ink),
          ),
        ),
      ),
    );
  }
}
