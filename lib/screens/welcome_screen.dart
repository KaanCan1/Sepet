import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';
import '../data/session.dart';
import '../state/auth_cubit.dart';
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
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  /// Sağlayıcı girişi.
  ///
  /// Şimdilik sunucudaki /auth/dev-login'e gidiyor; gerçek Apple/Google akışı
  /// üyelik ve istemci kimlikleri alınınca sağlayıcının kimlik token'ını
  /// doğrulayacak. Değişen tek yer burası olacak — jetonu saklayan ve
  /// kullanan katman aynı kalıyor.
  Future<void> _signIn(AuthProvider provider, {String? email}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await auth.signIn(
        provider: provider,
        email:
            email ??
            switch (provider) {
              // Sağlayıcı akışı henüz sahte; adresler bilerek ayrı seçildi.
              // Apple → telefonda kullanılan gerçek hesap, boş başlıyor.
              // Google → simülatördeki demo hesabı, örnek veriyle dolu.
              // İkisi ayrı sunucuya bakıyor (telefon Render, simülatör yerel),
              // dolayısıyla demo fişler gerçek endekse hiç karışmıyor.
              AuthProvider.apple => 'kaan@privaterelay.appleid.com',
              AuthProvider.google => 'demo@sepet.app',
              AuthProvider.email => 'kaan@ornek.com',
            },
        name: provider == AuthProvider.email ? null : 'Kaan',
      );
      if (!mounted) return;
      await navigator.push(ConsentScreen.route(firstRun: true));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          content: Text(
            e.message,
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withEmail() async {
    final email = await Navigator.of(context)
        .push<String>(SignInScreen.route());
    if (email == null || !mounted) return;
    await _signIn(AuthProvider.email, email: email);
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
                  fontFamily: F.display,
                  fontFamilyFallback: F.displayFallback,
                  fontWeight: FontWeight.w800,
                  fontSize: 31,
                  height: 1.18,
                  letterSpacing: -1,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'TÜİK herkes için tek bir sepet varsayar.\nSeninki o değil.',
                style: TextStyle(fontSize: 13, height: 1.55, color: C.muted),
              ),
              const Spacer(flex: 3),
              _ProviderButton(
                key: const Key('welcome-apple'),
                glyph: Glyph.apple,
                label: 'Apple ile Giriş Yap',
                filled: true,
                onTap: _busy ? null : () => _signIn(AuthProvider.apple),
              ),
              const SizedBox(height: 10),
              _ProviderButton(
                key: const Key('welcome-google'),
                glyph: Glyph.google,
                label: 'Google ile oturum aç',
                onTap: _busy ? null : () => _signIn(AuthProvider.google),
              ),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 18),
              _ProviderButton(
                key: const Key('welcome-email'),
                label: 'E-posta ile devam et',
                onTap: _busy ? null : _withEmail,
              ),
              const SizedBox(height: 18),
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

  /// null ise düğme sönük ve dokunmaya kapalı — giriş sürerken.
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = filled
        ? C.card.withValues(alpha: enabled ? 1 : .6)
        : C.ink.withValues(alpha: enabled ? 1 : .4);
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
