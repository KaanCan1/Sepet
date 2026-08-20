import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data/mock.dart';
import '../data/session.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'consent_screen.dart';
import 'privacy_screen.dart';

/// Giriş. Şimdilik e-posta ile sihirli bağlantı taklidi — gerçek uçlar
/// backend'e bağlanınca aynı ekran POST /auth/magic-link'e gidecek.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    fullscreenDialog: true,
    builder: (_) => const SignInScreen(),
  );

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _controller.text.trim();
    if (!isValidEmail(email)) return;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    // Ağ gecikmesini taklit et.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    session.value = Session(
      email: email,
      since: DateTime(2025, 9, 1),
      receipts: Mock.receiptCount,
      observations: Mock.observationCount,
    );
    navigator.pop();
    // Açık rıza aydınlatmadan ayrı ve girişten sonra sorulur (Kurul 2026/347).
    await navigator.push<void>(ConsentScreen.route(firstRun: true));
  }

  @override
  Widget build(BuildContext context) {
    final ok = isValidEmail(_controller.text);

    return ScreenFrame(
      title: 'Giriş',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.close, size: 17, color: C.muted, stroke: 1.6),
        ),
      ),
      footer: PrimaryButton(
        label: _busy ? 'Gönderiliyor…' : 'Devam et',
        onTap: ok && !_busy ? _submit : null,
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 12),
              const Text('Fişlerini\nhesabına bağla', style: T.display),
              const SizedBox(height: 10),
              const Text(
                'Parola yok. E-postana tek kullanımlık bir bağlantı gönderiyoruz.',
                style: TextStyle(fontSize: 12, height: 1.55, color: C.muted),
              ),
              const SizedBox(height: 22),
              const Lbl('E-POSTA'),
              const SizedBox(height: 6),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                borderColor: ok ? C.ink : C.line,
                child: CupertinoTextField(
                  controller: _controller,
                  placeholder: 'ad@ornek.com',
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  style: const TextStyle(fontSize: 14, color: C.ink),
                  placeholderStyle: const TextStyle(
                    fontSize: 14,
                    color: C.muted,
                  ),
                  onSubmitted: (_) => ok ? _submit() : null,
                ),
              ),
              // Boş alanda uyarı yok; yazmaya başlayıp geçersizse söyle.
              // Geçerliyken ağaçtan tamamen çıkıyor — görünmez bir hata
              // metnini ekran okuyucu yine de okurdu.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topLeft,
                child: _controller.text.isNotEmpty && !ok
                    ? const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Text(
                          'Geçerli bir e-posta adresi gir.',
                          style: TextStyle(fontSize: 11, color: C.hot),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 20),
              const Hairline(),
              const SizedBox(height: 14),
              const _Bullet(
                'Fişin fotoğrafı cihazdan çıkmaz. Metin cihaz üstünde okunur.',
              ),
              const _Bullet(
                'Hesabına yalnızca eşleşmiş satırlar gider: ürün, tutar, '
                'tarih, market.',
              ),
              const _Bullet(
                'Geriye dönük enflasyon analizi ve cihaz değişikliği bunun '
                'için gerekli.',
              ),
              const SizedBox(height: 4),
              Pressable(
                onTap: () => Navigator.of(context).push(PrivacyScreen.route()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: C.line)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aydınlatma metni',
                          style: TextStyle(fontSize: 12.5, color: C.ink),
                        ),
                      ),
                      LineIcon(Glyph.chevron, size: 13, color: C.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 9),
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: C.muted,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: C.muted),
          ),
        ),
      ],
    ),
  );
}
