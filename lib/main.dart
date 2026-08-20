import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shell.dart';
import 'theme/tokens.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const SepetApp());
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
      home: const Shell(),
    );
  }
}
