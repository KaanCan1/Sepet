import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data/session.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/screen_frame.dart';
import 'privacy_screen.dart';

/// Giriş. Şimdilik e-posta ile sihirli bağlantı taklidi — gerçek uçlar
/// backend'e bağlanınca aynı ekran POST /auth/magic-link'e gidecek.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  static Route<String> route() => CupertinoPageRoute<String>(
    fullscreenDialog: true,
    builder: (_) => const SignInScreen(),
  );

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _controller = TextEditingController();

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

  /// E-postayı karşılama ekranına döndürür; girişi orası yapıyor.
  void _submit() {
    final email = _controller.text.trim();
    if (!isValidEmail(email)) return;
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final ok = isValidEmail(_controller.text);

    return ScreenFrame(
      showTopBar: false,
      footer: PrimaryButton(label: 'Devam et', onTap: ok ? _submit : null),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              // Üst barda "Giriş", altında "Fişlerini hesabına bağla"
              // yazıyordu. İkincisi ekranın ne işe yaradığını söylüyor,
              // birincisi yalnızca adını; kalan o.
              LargeTitle(
                'Fişlerini\nhesabına bağla',
                onClose: () => Navigator.of(context).pop(),
              ),
              Text(
                'Parola yok. E-postana tek kullanımlık bir bağlantı gönderiyoruz.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: context.c.muted,
                ),
              ),
              const SizedBox(height: 22),
              const Lbl('E-POSTA'),
              const SizedBox(height: 6),
              // Kutu yerine alt çizgi. Çizgi geçerli e-postada koyulaşıyor —
              // kutunun kenar rengiyle yaptığı işin aynısı, daha az mürekkeple.
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ok ? context.c.ink : context.c.line,
                    ),
                  ),
                ),
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
                  padding: const EdgeInsets.only(bottom: 10),
                  style: TextStyle(fontSize: 14, color: context.c.ink),
                  placeholderStyle: TextStyle(
                    fontSize: 14,
                    color: context.c.muted,
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
                    ? Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Text(
                          'Geçerli bir e-posta adresi gir.',
                          style: TextStyle(fontSize: 11, color: context.c.hot),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              // Ayraç çizgisi kalktı: alanın kendi alt çizgisi zaten hemen
              // üstünde duruyordu ve ikisi çift çizgi gibi okunuyordu.
              // Formu maddelerden ayırma işini boşluk yapıyor.
              const SizedBox(height: 26),
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
              ActionRow(
                label: 'Aydınlatma metni',
                hint: 'KVKK',
                onTap: () => Navigator.of(context).push(PrivacyScreen.route()),
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
          decoration: BoxDecoration(
            color: context.c.muted,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: context.c.muted,
            ),
          ),
        ),
      ],
    ),
  );
}
