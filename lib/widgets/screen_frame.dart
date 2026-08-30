import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../screens/shell.dart';
import '../theme/tokens.dart';
import 'glass.dart';
import 'pull_refresh.dart';

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
    this.onRefresh,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> slivers;

  /// Alta sabitlenen buzlu cam eylem çubuğu ("Sepete ekle" gibi).
  final Widget? footer;

  final bool reserveTabBar;
  final bool showTopBar;

  /// Aşağı çekince çalışan tazeleme. Verilmezse gösterge hiç kurulmuyor.
  ///
  /// Döndürdüğü Future işin bitişini söylüyor: gösterge ona bakarak
  /// toplanıyor. Sabit süreli bir animasyon, yavaş ağda veri gelmeden
  /// "güncel" der.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final bottomReserve = (reserveTabBar ? kTabBarHeight + pad.bottom : 0.0);

    return Scaffold(
      backgroundColor: context.c.paper,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Yenileme denetimi İLK sliver olmak zorunda. Üst boşluğun
              // arkasına konunca aşırı kaydırma ona hiç ulaşmıyor ve
              // gösterge sessizce hiç çıkmıyordu.
              if (onRefresh != null)
                CupertinoSliverRefreshControl(
                  // Eşik AŞIRI KAYDIRMA pikseli cinsinden, parmak yolu
                  // değil. Zıplayan fizik çekişi sönümlediği için 110'luk
                  // eşik ekranda 270 piksellik bir çekişe denk geliyordu —
                  // kimsenin o kadar çekmesi beklenmez. 80 ölçülerek
                  // seçildi: yaklaşık 180 piksel, rahat bir başparmak
                  // hareketi, ama kazara kaydırmayla ulaşılacak kadar da
                  // kısa değil.
                  refreshTriggerPullDistance: 80,
                  refreshIndicatorExtent: 68,
                  onRefresh: onRefresh,
                  builder: (context, mode, pulled, trigger, _) =>
                      PaperRefreshIndicator(
                        mode: mode,
                        pulled: pulled,
                        trigger: trigger,
                      ),
                ),
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
          color: !enabled
              ? context.c.card
              : (dark ? context.c.ink : context.c.card),
          border: Border.all(
            color: !enabled
                ? context.c.line
                : (dark ? context.c.ink : context.c.line),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: !enabled
                ? context.c.muted
                : (dark ? context.c.card : context.c.ink),
          ),
        ),
      ),
    );
  }
}
