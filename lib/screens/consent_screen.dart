import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/auth_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
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
          title: 'İzinler',
          leading: widget.firstRun
              ? null
              : Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: LineIcon(
                      Glyph.back,
                      size: 17,
                      color: context.c.ink,
                      stroke: 1.6,
                    ),
                  ),
                ),
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
                  const SizedBox(height: 6),
                  const Text('İsteğe bağlı\nizinler', style: T.display),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 18),
                  Pressable(
                    onTap: () =>
                        Navigator.of(context).push(PrivacyScreen.route()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: context.c.line),
                          bottom: BorderSide(color: context.c.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Aydınlatma metni',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.c.ink,
                              ),
                            ),
                          ),
                          LineIcon(
                            Glyph.chevron,
                            size: 13,
                            color: context.c.muted,
                          ),
                        ],
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
    borderColor: value ? context.c.ink : context.c.line,
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
