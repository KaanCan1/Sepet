import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/auth_cubit.dart';
import '../theme/tokens.dart';
import 'shell.dart';
import 'welcome_screen.dart';

/// Uygulamanın kökü. Giriş zorunlu: oturum yoksa karşılama ekranı, varsa kabuk.
///
/// Jeton Keychain'de duruyor; AuthCubit açılışta bir kez okuyup doğruluyor,
/// süresi dolmuşsa sessizce giriş ekranına düşülüyor. Okuma sürerken
/// AuthUnknown durumu var — onsuz karşılama ekranı bir kare görünüp sonra
/// kabuğa atlıyordu.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => switch (state) {
        // Boş kâğıt zemin beyaz sıçramayı engelliyor.
        AuthUnknown() => ColoredBox(color: context.c.paper),
        AuthSignedOut() => const WelcomeScreen(),
        AuthSignedIn() => const Shell(),
      },
    );
  }
}
