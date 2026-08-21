import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        light: const GlassThemeVariant(settings: GlassSettings.theme),
        dark: const GlassThemeVariant(settings: GlassSettings.theme),
        brightness: Brightness.light,
      ),
      child: AppScope(child: const SepetApp()),
    ),
  );
}

class SepetApp extends StatelessWidget {
  const SepetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sepet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.paper,
        colorScheme: ColorScheme.fromSeed(seedColor: C.ink, surface: C.paper),
        // Sayfa geçişleri her platformda iOS gibi kaysın.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: const TextTheme().apply(
          bodyColor: C.ink,
          displayColor: C.ink,
        ),
      ),
      // Tek yerel: Türkçe. Sayı/tarih biçimlendirmesi Fmt üzerinden.
      locale: const Locale('tr', 'TR'),
      builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
      home: const RootGate(),
    );
  }
}
