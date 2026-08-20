import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/tokens.dart';
import 'shell.dart';
import 'welcome_screen.dart';

/// Uygulamanın kökü: ilk açılışta karşılama ekranı, sonrasında doğrudan kabuk.
///
/// Bayrak oturumdan bağımsız kalıcı — hesapsız devam eden kullanıcı her
/// açılışta aynı duvarla karşılaşmasın.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  static const seenKey = 'onboarding_seen_v1';

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _seen = prefs.getBool(RootGate.seenKey) ?? false);
  }

  Future<void> _markSeen() async {
    setState(() => _seen = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(RootGate.seenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    // Disk okuması bir kareden kısa; boş kâğıt zemin sıçramayı engelliyor.
    if (_seen == null) return const ColoredBox(color: C.paper);
    return _seen! ? const Shell() : WelcomeScreen(onDone: _markSeen);
  }
}
