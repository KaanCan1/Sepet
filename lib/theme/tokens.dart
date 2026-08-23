import 'package:flutter/widgets.dart';

/// Tasarım taslağındaki CSS değişkenlerinin birebir karşılığı.
/// Renk tek yerde harcanır: zam kırmızısı (`hot`). Geri kalanı kâğıt fiş.
abstract final class C {
  static const paper = Color(0xFFF7F6F3);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16181A);
  static const muted = Color(0xFF7A7975);
  static const line = Color(0xFFE8E6E1);
  static const hot = Color(0xFF9F2F2D);
  static const hotBg = Color(0xFFFDEBEC);
  static const ref = Color(0xFF46586B);
  static const refBg = Color(0xFFECEFF2);

  /// Pasif bar dolgusu ve ikincil seri rengi.
  static const grey = Color(0xFFB9B6AE);
}

/// Fiş yazıcısı mantığı: sayılar monospace, başlıklar serif.
abstract final class F {
  /// Vitrin: Gotham'ın ücretsiz en yakın karşılığı (Montserrat). Kelime
  /// işareti, manşet sayı ve büyük başlıklarda — gövde metninde değil.
  static const display = 'Sepet Display';
  static const displayFallback = [
    'Avenir Next',
    'Helvetica Neue',
    'sans-serif',
  ];

  static const serif = 'Sepet Serif';
  static const serifFallback = [
    'Iowan Old Style',
    'Palatino',
    'Georgia',
    'serif',
  ];
  static const mono = 'Sepet Mono';
  static const monoFallback = ['SF Mono', 'Menlo', 'monospace'];
}

abstract final class T {
  /// .eyebrow / .lbl — 9.5px mono, letter-spacing .12em, uppercase
  static const label = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 9.5,
    height: 1.3,
    letterSpacing: 1.14,
    color: C.muted,
  );

  /// .bigno — 60px serif
  static const bigNumber = TextStyle(
    fontFamily: F.display,
    fontFamilyFallback: F.displayFallback,
    fontWeight: FontWeight.w800,
    fontSize: 60,
    height: .95,
    letterSpacing: -2.4,
    color: C.ink,
  );

  /// .prod — 24px serif
  static const display = TextStyle(
    fontFamily: F.display,
    fontFamilyFallback: F.displayFallback,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -.6,
    color: C.ink,
  );

  /// .topbar .t — 13px 600
  static const title = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -.13,
    color: C.ink,
  );

  static const body = TextStyle(fontSize: 12, height: 1.35, color: C.ink);

  /// .v / .p — monospace sayı
  static const num12 = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 12,
    color: C.ink,
  );

  static const num11 = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 11,
    color: C.ink,
  );

  /// .raw — fişteki ham satır
  static const raw = TextStyle(
    fontFamily: F.mono,
    fontFamilyFallback: F.monoFallback,
    fontSize: 8.5,
    height: 1.4,
    color: C.muted,
  );
}
