import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/session.dart';
import '../theme/tokens.dart';
import 'shell.dart';
import 'welcome_screen.dart';

/// Uygulamanın kökü. Giriş zorunlu: oturum yoksa karşılama ekranı, varsa kabuk.
///
/// Jeton Keychain'de duruyor, açılışta bir kez okunup doğrulanıyor — süresi
/// dolmuşsa sessizce giriş ekranına düşülüyor.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    await AppScope.of(context).restoreSession();
    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) {
    // Keychain okuması kısa; boş kâğıt zemin beyaz sıçramayı engelliyor.
    if (_restoring) return const ColoredBox(color: C.paper);

    return ValueListenableBuilder<Session?>(
      valueListenable: session,
      builder: (context, s, _) =>
          s == null ? const WelcomeScreen() : const Shell(),
    );
  }
}
