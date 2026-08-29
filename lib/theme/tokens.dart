import 'package:flutter/material.dart';

/// Uygulamanın renk kümesi — **iki takım**, biri açık biri koyu tema için.
///
/// Renkler artık derleme zamanı sabiti değil, `ThemeExtension`. Sebebi somut:
/// uygulama telefonun temasını izliyor ve aynı `C.ink` iki temada iki farklı
/// değer olmak zorunda. Sabit kalsalardı koyu temada kâğıt beyazı zemine
/// siyah metin yazmaya devam ederdik.
///
/// Kullanım: `context.c.ink`. [BuildContext.c] kısayolu bu dosyanın sonunda.
@immutable
class SepetColors extends ThemeExtension<SepetColors> {
  const SepetColors({
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.track,
    required this.glass,
    required this.glassEdge,
    required this.hot,
    required this.hotBg,
    required this.ref,
    required this.refBg,
    required this.grey,
    required this.category,
    required this.areaFade,
  });

  /// Ekran zemini ve yüzeyler.
  final Color paper, card;

  /// Metin: birincil, ikincil, en soluk (etiketler).
  final Color ink, muted, faint;

  /// Ayırıcı çizgi ve pasif bar oluğu.
  final Color line, track;

  /// Yüzen sekme çubuğunun camı ve üst kenar ışığı.
  final Color glass, glassEdge;

  /// Yön: artış kırmızısı ve zemini.
  final Color hot, hotBg;

  /// Resmî seri (TÜİK TÜFE) ve zemini.
  final Color ref, refBg;

  /// Pasif dolgu.
  final Color grey;

  /// Kategori renkleri — altı adet, sırası `CategoryPalette` ile sabit.
  ///
  /// **Renk yalnızca grafiklerde harcanıyor**: çizgi, bar, kıvılcım. Başlık,
  /// düğme ve sekme nötr kalıyor, böylece renk gördüğün her yerde bir veri
  /// var. Tonlar mat: doygun renkler ekranı ucuzlatıyordu.
  ///
  /// Her ton kendi zemininde en az 4,7:1 kontrast veriyor — bu renkler 12
  /// piksellik yüzde sayılarında da kullanılıyor, dekoratif değiller.
  final List<Color> category;

  /// Grafik alan dolgusunun opaklığı. Koyu temada daha yüksek: mat renk
  /// siyah zeminde daha çabuk kayboluyor.
  final double areaFade;

  /// Açık tema — esas olan bu.
  static const light = SepetColors(
    paper: Color(0xFFFBFBF9),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0F1214),
    muted: Color(0xFF6B7276),
    faint: Color(0xFF9AA1A5),
    line: Color(0x170F1214),
    track: Color(0x0F0F1214),
    glass: Color(0xB8FBFBF9),
    glassEdge: Color(0xE6FFFFFF),
    hot: Color(0xFF9E4A44),
    hotBg: Color(0xFFF3E7E6),
    ref: Color(0xFF616F84),
    refBg: Color(0xFFECEFF2),
    grey: Color(0xFFB9B6AE),
    category: [
      Color(0xFFA85751), // Et
      Color(0xFF427A56), // Meyve · sebze
      Color(0xFF836C2D), // Süt · yumurta
      Color(0xFF9C6640), // Ekmek · tahıl
      Color(0xFF4A7691), // İçecek
      Color(0xFF75689C), // Temizlik
    ],
    areaFade: .18,
  );

  /// Koyu tema — telefon karanlığa geçince bu geliyor.
  static const dark = SepetColors(
    paper: Color(0xFF0C0F11),
    card: Color(0xFF161B1E),
    ink: Color(0xFFF1F4F5),
    muted: Color(0xFF98A3A8),
    faint: Color(0xFF6C767B),
    line: Color(0x1AFFFFFF),
    track: Color(0x12FFFFFF),
    glass: Color(0xB80C0F11),
    glassEdge: Color(0x24FFFFFF),
    hot: Color(0xFFD08C84),
    hotBg: Color(0xFF2A1D1C),
    ref: Color(0xFF9AA8BA),
    refBg: Color(0xFF1B2126),
    grey: Color(0xFF5B6367),
    category: [
      Color(0xFFCB8179),
      Color(0xFF7FB392),
      Color(0xFFC4AC6C),
      Color(0xFFCE9C72),
      Color(0xFF7FA5BD),
      Color(0xFFA399C6),
    ],
    areaFade: .22,
  );

  @override
  SepetColors copyWith({
    Color? paper,
    Color? card,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? line,
    Color? track,
    Color? glass,
    Color? glassEdge,
    Color? hot,
    Color? hotBg,
    Color? ref,
    Color? refBg,
    Color? grey,
    List<Color>? category,
    double? areaFade,
  }) => SepetColors(
    paper: paper ?? this.paper,
    card: card ?? this.card,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    faint: faint ?? this.faint,
    line: line ?? this.line,
    track: track ?? this.track,
    glass: glass ?? this.glass,
    glassEdge: glassEdge ?? this.glassEdge,
    hot: hot ?? this.hot,
    hotBg: hotBg ?? this.hotBg,
    ref: ref ?? this.ref,
    refBg: refBg ?? this.refBg,
    grey: grey ?? this.grey,
    category: category ?? this.category,
    areaFade: areaFade ?? this.areaFade,
  );

  @override
  SepetColors lerp(covariant SepetColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SepetColors(
      paper: c(paper, other.paper),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      line: c(line, other.line),
      track: c(track, other.track),
      glass: c(glass, other.glass),
      glassEdge: c(glassEdge, other.glassEdge),
      hot: c(hot, other.hot),
      hotBg: c(hotBg, other.hotBg),
      ref: c(ref, other.ref),
      refBg: c(refBg, other.refBg),
      grey: c(grey, other.grey),
      category: [
        for (var i = 0; i < category.length; i++)
          c(category[i], other.category[i]),
      ],
      areaFade: areaFade + (other.areaFade - areaFade) * t,
    );
  }
}

/// **Geçiş köprüsü.** Ekranlar hâlâ `C.ink` yazıyor; hepsini tek seferde
/// çevirmek 300'den fazla noktaya dokunan, gözden geçirilemez bir yama
/// olurdu. Bu sınıf açık temanın değerlerini veriyor ve ekranlar
/// `context.c`'ye taşındıkça küçülüyor. Sıfırlanınca silinecek —
/// o güne kadar koyu tema açılmıyor, çünkü buradaki değerler sabit.
@Deprecated('context.c kullan; bu köprü geçiş bitince silinecek')
abstract final class C {
  static const paper = Color(0xFFFBFBF9);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1214);
  static const muted = Color(0xFF6B7276);
  static const line = Color(0x170F1214);
  static const hot = Color(0xFF9E4A44);
  static const hotBg = Color(0xFFF3E7E6);
  static const ref = Color(0xFF616F84);
  static const refBg = Color(0xFFECEFF2);
  static const grey = Color(0xFFB9B6AE);
}

/// `context.c.ink` — her widget'ta `Theme.of(context).extension<...>()!`
/// yazmamak için.
extension SepetColorsX on BuildContext {
  SepetColors get c => Theme.of(this).extension<SepetColors>()!;
}

/// Kategori adından renk indeksine sabit eşleme.
///
/// Sıra kritik: aynı kategori her ekranda aynı rengi almalı, yoksa renk
/// öğrenilebilir bir dil olmaktan çıkar. Sunucudan gelen ad eşleşmezse
/// karma üzerinden dağıtılıyor — rastgele ama kararlı.
int categoryIndex(String name) {
  const known = ['Et', 'Meyve', 'Süt', 'Ekmek', 'İçecek', 'Temizlik'];
  for (var i = 0; i < known.length; i++) {
    if (name.startsWith(known[i])) return i;
  }
  return name.hashCode.abs() % known.length;
}

/// Yazı tipleri.
///
/// Vitrin fontu (Montserrat) düştü: arayüz artık sistem fontunu kullanıyor —
/// iOS'ta SF Pro. Sayılar monospace kalıyor, çünkü tablo rakamı olmadan
/// sütunlar hizalanmıyor ve değişen sayılar zıplıyor.
abstract final class F {
  /// Arayüz: sistem fontu. `null` vermek Flutter'a platformun kendi
  /// fontunu kullandırıyor.
  static const String? ui = null;

  static const mono = 'Sepet Mono';
  static const monoFallback = ['SF Mono', 'Menlo', 'monospace'];

  /// Fişin ham metnini gösteren yerlerde duruyor.
  static const serif = 'Sepet Serif';
  static const serifFallback = [
    'Iowan Old Style',
    'Palatino',
    'Georgia',
    'serif',
  ];
}

/// Tipografi ölçeği. **Renk taşımıyorlar** — rengi tema veriyor, kullanım
/// yerinde `.copyWith(color: context.c.x)` ile geçiliyor.
abstract final class T {
  /// Küçük mono etiket. Metin ZATEN büyük harfle yazılır — Dart'ın
  /// `toUpperCase()`'i Türkçe'de i → I yapıp noktayı düşürüyor.
  static const label = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 9.5,
    height: 1.3,
    letterSpacing: 1.14,
  );

  /// Manşet sayı — monospace, tablo rakamı.
  static const bigNumber = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontWeight: FontWeight.w600,
    fontSize: 52,
    height: 1,
    letterSpacing: -2.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Ekran başlığı — büyük, üst barsız.
  static const largeTitle = TextStyle(
    fontFamily: F.ui,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.1,
    letterSpacing: -.78,
  );

  /// Ürün adı gibi orta başlıklar.
  static const display = TextStyle(
    fontFamily: F.ui,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    height: 1.2,
    letterSpacing: -.38,
  );

  static const title = TextStyle(
    fontFamily: F.ui,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -.13,
  );

  static const body = TextStyle(fontFamily: F.ui, fontSize: 12, height: 1.35);

  /// Satır adı.
  static const rowName = TextStyle(
    fontFamily: F.ui,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -.14,
  );

  static const num12 = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const num11 = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 11,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Sağa hizalı değer.
  static const value = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// .raw — fişteki ham satır
  static const raw = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 8.5,
    height: 1.4,
  );
}
