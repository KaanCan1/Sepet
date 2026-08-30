import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'data/app_scope.dart';
import 'screens/root_gate.dart';
import 'widgets/glass.dart';
import 'theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  // Shader'ları önden ısıt — ilk karede beyaz sıçrama olmasın.
  await LiquidGlassWidgets.initialize();

  runApp(
    LiquidGlassWidgets.wrap(
      // Paket Material'a bağlı değil; parlaklığı bu köprüyle okuyor.
      brightnessResolver: Theme.maybeBrightnessOf,
      theme: GlassThemeData(
        light: GlassThemeVariant(settings: GlassSettings.theme),
        dark: GlassThemeVariant(settings: GlassSettings.theme),
        brightness: Brightness.light,
      ),
      child: AppScope(child: const SepetApp()),
    ),
  );
}

/// İki tema tek yerden kuruluyor; aralarındaki tek fark renk kümesi.
ThemeData _theme(SepetColors c, Brightness brightness) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  scaffoldBackgroundColor: c.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: c.hot,
    brightness: brightness,
    surface: c.paper,
  ),
  extensions: [c],
  // Sayfa geçişleri her platformda iOS gibi kaysın.
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  ),
  textTheme: const TextTheme().apply(bodyColor: c.ink, displayColor: c.ink),
);

class SepetApp extends StatelessWidget {
  const SepetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sepet',
      debugShowCheckedModeBanner: false,
      // Tema telefondan geliyor. Uygulama içi bir anahtar yok: sistem
      // karanlığa geçince uygulama da geçiyor.
      themeMode: ThemeMode.system,
      theme: _theme(SepetColors.light, Brightness.light),
      darkTheme: _theme(SepetColors.dark, Brightness.dark),
      // Tek yerel: Türkçe. Sayı/tarih biçimlendirmesi Fmt üzerinden.
      locale: const Locale('tr', 'TR'),
      // Tarih seçici Türkçe olsun; delegeler olmadan İngilizce açılıyor.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
      builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
      home: const RootGate(),
    );
  }
}
