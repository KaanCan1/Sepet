import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/session.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import 'consent_screen.dart';
import 'privacy_screen.dart';
import 'sign_in_screen.dart';

/// İlk açılış ekranı. Giriş zorunlu değil — "hesapsız devam et" yolu, fişlerin
/// cihazda kalması vaadini koruyor.
///
/// KVKK: burada yalnızca **aydınlatma metnine** link var. Aydınlatma
/// bilgilendirmedir, rıza değildir; açık rıza [ConsentScreen]'de ayrı ve
/// varsayılanı kapalı duruyor. Bu ekran bir onay kutusuna dönüştürülmemeli.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onDone});

  /// İlk açılış bayrağını yazıp kabuğa geçmek için — kök geçidi veriyor.
  final VoidCallback onDone;

  Future<void> _signInWith(BuildContext context, AuthProvider provider) async {
    // Mock: gerçek OAuth, Apple Developer üyeliği ve Google istemci kimlikleri
    // alındıktan sonra `sign_in_with_apple` / `google_sign_in` ile gelecek.
    final navigator = Navigator.of(context);
    session.value = Session(
      email: switch (provider) {
        AuthProvider.apple => 'kaan@privaterelay.appleid.com',
        AuthProvider.google => 'kaan@gmail.com',
        AuthProvider.email => 'kaan@ornek.com',
      },
      provider: provider,
      name: provider == AuthProvider.email ? null : 'Kaan',
      since: DateTime(2025, 9, 1),
      receipts: Mock.receiptCount,
      observations: Mock.observationCount,
    );
    await navigator.push(ConsentScreen.route(firstRun: true));
    onDone();
  }

  Future<void> _withEmail(BuildContext context) async {
    final navigator = Navigator.of(context);
    await navigator.push(SignInScreen.route());
    if (session.value == null) return;
    await navigator.push(ConsentScreen.route(firstRun: true));
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: C.paper,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, pad.bottom > 0 ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const _Wordmark(),
              const Spacer(),
              const Text(
                'Kendi enflasyonunu\nkendi fişinden ölç',
                style: TextStyle(
                  fontFamily: F.serif,
                  fontFamilyFallback: F.serifFallback,
                  fontSize: 32,
                  height: 1.15,
                  letterSpacing: -.7,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'TÜİK ve ENAG herkes için tek bir sepet varsayar.\nSeninki o değil.',
                style: TextStyle(fontSize: 13, height: 1.55, color: C.muted),
              ),
              const Spacer(flex: 3),
              _ProviderButton(
                key: const Key('welcome-apple'),
                glyph: Glyph.apple,
                label: 'Apple ile Giriş Yap',
                filled: true,
                onTap: () => _signInWith(context, AuthProvider.apple),
              ),
              const SizedBox(height: 10),
              _ProviderButton(
                key: const Key('welcome-google'),
                glyph: Glyph.google,
                label: 'Google ile oturum aç',
                onTap: () => _signInWith(context, AuthProvider.google),
              ),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 18),
              _ProviderButton(
                key: const Key('welcome-email'),
                label: 'E-posta ile devam et',
                onTap: () => _withEmail(context),
              ),
              const SizedBox(height: 18),
              Pressable(
                key: const Key('welcome-skip'),
                onTap: onDone,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Şimdilik hesapsız devam et',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: C.muted),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Pressable(
                onTap: () => Navigator.of(context).push(PrivacyScreen.route()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aydınlatma Metni',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: C.muted,
                      decoration: TextDecoration.underline,
                      decorationColor: C.line,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Serif kelime işareti, iki yanında fişin koparma çizgisi.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 56, child: TearEdge()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'SEPET',
          style: T.label.copyWith(fontSize: 12, letterSpacing: 4, color: C.ink),
        ),
      ),
      const SizedBox(width: 56, child: TearEdge()),
    ],
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Hairline()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('veya', style: T.label.copyWith(fontSize: 10)),
      ),
      const Expanded(child: Hairline()),
    ],
  );
}

/// Sağlayıcı düğmesi.
///
/// Apple HIG düğmenin görünümünü şarta bağlıyor: siyah/beyaz/çerçeveli üç
/// varyant, yerelleştirilmiş metin ve metnin yanında elma işareti. Dolu varyant
/// bizim ink düğmemizle örtüştüğü için tasarım dilinden sapmıyoruz.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    super.key,
    this.glyph,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final Glyph? glyph;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? C.card : C.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: filled ? C.ink : C.card,
          border: Border.all(color: filled ? C.ink : C.line),
          borderRadius: BorderRadius.circular(10),
        ),
        // Simge solda sabit, metin ortada. Grup birlikte ortalanırsa metin
        // uzunluğu simgeyi kaydırıyor ve düğmeler arasında hiza bozuluyor.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
            if (glyph != null)
              Positioned(
                left: 18,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(child: LineIcon(glyph!, size: 20, color: fg)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
