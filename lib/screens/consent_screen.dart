import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/session.dart';
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
    return ValueListenableBuilder<Session?>(
      valueListenable: session,
      builder: (context, s, _) => ScreenFrame(
        title: 'İzinler',
        leading: widget.firstRun
            ? null
            : Pressable(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: LineIcon(
                    Glyph.back,
                    size: 17,
                    color: C.ink,
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
                const Text(
                  'Endeksin hesaplanması için bunlara ihtiyaç yok. İkisi de '
                  'kapalıyken uygulama aynen çalışır.',
                  style: TextStyle(fontSize: 12, height: 1.55, color: C.muted),
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
                      session.value = s?.copyWith(consentAggregate: v),
                ),
                const SizedBox(height: 10),
                _ConsentTile(
                  title: 'Pazarlama iletileri',
                  body: 'Yeni özellikler ve aylık bülten e-posta ile gelsin.',
                  value: s?.consentMarketing ?? false,
                  onChanged: (v) =>
                      session.value = s?.copyWith(consentMarketing: v),
                ),
                const SizedBox(height: 18),
                Pressable(
                  onTap: () =>
                      Navigator.of(context).push(PrivacyScreen.route()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: C.line),
                        bottom: BorderSide(color: C.line),
                      ),
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
                const SizedBox(height: 12),
                const Text(
                  'Verdiğin rızayı istediğin an bu ekrandan geri alabilirsin. '
                  'Geri aldığında ilgili işleme durur.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: C.muted),
                ),
              ],
            ),
          ),
        ],
      ),
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
    borderColor: value ? C.ink : C.line,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, color: C.ink)),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: C.muted,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: C.card,
          activeTrackColor: C.ink,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
