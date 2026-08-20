import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/mock.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'consent_screen.dart';
import 'privacy_screen.dart';
import 'sign_in_screen.dart';

/// Profil. Giriş yapılmadan endeks yine hesaplanır — ama fişler yalnızca
/// cihazda kalır. Giriş, geriye dönük analizin ve cihaz değiştirince
/// kaybetmemenin karşılığı.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _monthlyPush = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Session?>(
      valueListenable: session,
      builder: (context, s, _) => ScreenFrame(
        title: 'Profil',
        reserveTabBar: true,
        slivers: [
          SliverPadding(
            padding: kGutter,
            sliver: SliverList.list(
              children: [
                const SizedBox(height: 8),
                if (s == null) _SignedOut() else _Identity(session: s),
                const SizedBox(height: 22),
                const Lbl('KARŞILAŞTIRMA KAYNAKLARI'),
                const SizedBox(height: 8),
                PaperCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < Mock.sources.length; i++) ...[
                        if (i > 0) const Hairline(),
                        _SourceRow(source: Mock.sources[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Resmî ve bağımsız iki ölçüm yan yana duruyor. Uygulama '
                  'hiçbirini doğrulamıyor ya da yorumlamıyor — senin sepetin '
                  'için referans çizgisi olarak çekiliyorlar.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: C.muted),
                ),
                const SizedBox(height: 22),
                const Lbl('BİLDİRİM'),
                const SizedBox(height: 8),
                PaperCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aylık kart',
                              style: TextStyle(fontSize: 12.5, color: C.ink),
                            ),
                            SizedBox(height: 3),
                            Text(
                              "Her ayın 3'ünde, resmî veri açıklandığında",
                              style: TextStyle(fontSize: 11, color: C.muted),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _monthlyPush,
                        activeColor: C.card,
                        activeTrackColor: C.ink,
                        onChanged: (v) => setState(() => _monthlyPush = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Lbl('VERİLERİN'),
                const SizedBox(height: 4),
                if (s != null)
                  _ActionRow(
                    label: 'İzinler',
                    hint: _consentHint(s),
                    onTap: () =>
                        Navigator.of(context).push(ConsentScreen.route()),
                  ),
                _ActionRow(
                  label: 'Aydınlatma metni',
                  hint: 'KVKK',
                  onTap: () =>
                      Navigator.of(context).push(PrivacyScreen.route()),
                ),
                _ActionRow(
                  label: 'Fişleri dışa aktar',
                  hint: 'CSV',
                  onTap: () => _toast(context, 'Dışa aktarma hazırlanıyor'),
                ),
                _ActionRow(
                  label: 'Fiş verisi nerede duruyor?',
                  hint: s == null ? 'Cihazda' : 'Cihaz + hesap',
                  onTap: () => _explainStorage(context, s != null),
                ),
                if (s != null)
                  _ActionRow(
                    label: 'Hesabı sil',
                    hint: '',
                    danger: true,
                    onTap: () => _confirmDelete(context),
                  ),
                const SizedBox(height: 18),
                if (s != null)
                  PrimaryButton(
                    label: 'Çıkış yap',
                    dark: false,
                    onTap: () => session.value = null,
                  ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'SEPET · v0.1.0',
                    style: T.label.copyWith(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _consentHint(Session s) {
    final n = (s.consentAggregate ? 1 : 0) + (s.consentMarketing ? 1 : 0);
    return n == 0 ? 'Yok' : '$n açık';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            msg,
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
  }

  void _explainStorage(BuildContext context, bool signedIn) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Fiş verisi', style: T.title),
        content: Text(
          signedIn
              ? 'Fişin fotoğrafı cihazdan çıkmıyor. Metin, cihaz üstünde '
                    'okunduktan sonra yalnızca eşleşmiş satırlar (ürün, tutar, '
                    'tarih, market) hesabına kaydediliyor. Geriye dönük analiz '
                    've cihaz değişikliği bunun için gerekli.'
              : 'Giriş yapmadığın için her şey yalnızca bu cihazda duruyor. '
                    'Uygulamayı silersen geçmişin de gider.',
          style: const TextStyle(fontSize: 12.5, height: 1.5, color: C.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anladım', style: TextStyle(color: C.ink)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Hesabı sil', style: T.title),
        content: const Text(
          'Tüm fişlerin ve endeks geçmişin kalıcı olarak silinir. '
          'Bu işlem geri alınamaz.',
          style: TextStyle(fontSize: 12.5, height: 1.5, color: C.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              session.value = null;
            },
            child: const Text('Sil', style: TextStyle(color: C.hot)),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Lbl('HESAP'),
        const SizedBox(height: 4),
        const Text('Fişlerin\nsende kalsın', style: T.display),
        const SizedBox(height: 10),
        const Text(
          'Giriş yaparsan fişlerin hesabına bağlanır: cihaz değişince '
          'geçmişin gitmez, endeksin geriye dönük olarak yeniden hesaplanabilir.',
          style: TextStyle(fontSize: 12, height: 1.55, color: C.muted),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Giriş yap',
          onTap: () => Navigator.of(context).push(SignInScreen.route()),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: C.ink,
                shape: BoxShape.circle,
              ),
              child: Text(
                session.initials,
                style: T.display.copyWith(fontSize: 20, color: C.card),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayName,
                    style: T.display.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.email,
                    style: T.label.copyWith(fontSize: 10, letterSpacing: .3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        PaperCard(
          child: Row(
            children: [
              _Metric('FİŞ', '${session.receipts}'),
              _Metric('GÖZLEM', '${session.observations}'),
              _Metric(
                'ÜYELİK',
                '${Fmt.monthShort(session.since)} ${session.since.year % 100}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Lbl(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: F.mono,
            fontFamilyFallback: F.monoFallback,
            fontSize: 16,
            color: C.ink,
          ),
        ),
      ],
    ),
  );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});
  final DataSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: source.official ? C.ref : C.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${source.publisher} ${source.name}',
                      style: const TextStyle(fontSize: 12, color: C.ink),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      source.official ? 'RESMÎ' : 'BAĞIMSIZ',
                      style: T.label.copyWith(fontSize: 8.5),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'SON YAYIN ${Fmt.dayMonth(source.lastRelease)} · '
                  'SONRAKİ ${Fmt.dayMonth(source.nextRelease)}',
                  style: T.label.copyWith(fontSize: 8.5),
                ),
              ],
            ),
          ),
          Text(Fmt.pct1(source.value), style: T.num12),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.hint,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: .99,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: danger ? C.hot : C.ink),
            ),
          ),
          if (hint.isNotEmpty) ...[
            Text(hint, style: T.label.copyWith(fontSize: 9)),
            const SizedBox(width: 8),
          ],
          LineIcon(Glyph.chevron, size: 13, color: danger ? C.hot : C.muted),
        ],
      ),
    ),
  );
}
