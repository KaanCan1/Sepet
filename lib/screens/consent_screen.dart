import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/auth_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/screen_frame.dart';
import 'privacy_screen.dart';

/// Açık rıza — aydınlatma metninden AYRI ekran (Kurul 2026/347).
/// İkisi de isteğe bağlı ve varsayılan kapalı; rıza her an geri alınabilir.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, this.firstRun = false});

  /// Girişten hemen sonra gösteriliyorsa "Şimdilik geç" seçeneği çıkar.
  final bool firstRun;

  static Route<void> route({bool firstRun = false}) => CupertinoPageRoute(
    fullscreenDialog: firstRun,
    builder: (_) => ConsentScreen(firstRun: firstRun),
  );

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final s = switch (auth) {
          AuthSignedIn(:final session) => session,
          _ => null,
        };
        return ScreenFrame(
          showTopBar: false,
          footer: widget.firstRun
              ? PrimaryButton(
                  label: 'Devam et',
                  onTap: () => Navigator.of(context).pop(),
                )
              : null,
          slivers: [
            SliverPadding(
              padding: kGutter,
              sliver: SliverList.list(
                children: [
                  // İlk kurulumda geri dönülecek bir yer yok; sonradan
                  // profilden açıldığında var. Başlık o yüzden geri okunu
                  // koşullu taşıyor.
                  LargeTitle(
                    'İsteğe bağlı\nizinler',
                    onBack: widget.firstRun
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Endeksin hesaplanması için bunlara ihtiyaç yok. İkisi de '
                    'kapalıyken uygulama aynen çalışır.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: context.c.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ConsentTile(
                    title: 'Anonim endekse katkı',
                    body:
                        'Ürün ve fiyat gözlemlerin kimliğinden ayrılmış hâlde '
                        'ülke geneli sepet endeksine katılsın. Fiş görselin ya '
                        'da e-postan paylaşılmaz.',
                    value: s?.consentAggregate ?? false,
                    onChanged: (v) =>
                        context.read<AuthCubit>().setConsents(aggregate: v),
                  ),
                  const SizedBox(height: 10),
                  _ConsentTile(
                    title: 'Pazarlama iletileri',
                    body: 'Yeni özellikler ve aylık bülten e-posta ile gelsin.',
                    value: s?.consentMarketing ?? false,
                    onChanged: (v) =>
                        context.read<AuthCubit>().setConsents(marketing: v),
                  ),
                  const SizedBox(height: 6),
                  // Eskiden kendi üst VE alt çizgisini çiziyordu; üstteki
                  // izin satırının alt çizgisiyle üst üste binip çift çizgi
                  // yapıyordu. ActionRow yalnızca altını çiziyor.
                  ActionRow(
                    label: 'Aydınlatma metni',
                    hint: 'KVKK',
                    onTap: () =>
                        Navigator.of(context).push(PrivacyScreen.route()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verdiğin rızayı istediğin an bu ekrandan geri alabilirsin. '
                    'Geri aldığında ilgili işleme durur.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: context.c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  // Kutu yerine alt çizgi; çizgi izin açıkken koyulaşıyor — kutunun kenar
  // rengiyle yaptığı işin aynısı. Açık iznin görünür işareti zaten
  // anahtarın kendisi, kutu onu ikinci kez söylüyordu.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 2, bottom: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: value ? context.c.ink : context.c.line),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12.5, color: context.c.ink),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: context.c.muted,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: context.c.card,
          activeTrackColor: context.c.ink,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
