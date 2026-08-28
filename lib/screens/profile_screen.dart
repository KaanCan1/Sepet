import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';
import '../data/fmt.dart';
import '../data/repository.dart';
import '../state/app_data.dart';
import '../state/auth_cubit.dart';
import '../state/receipts_cubit.dart';
import '../state/index_cubit.dart';
import '../widgets/data_view.dart';
import '../data/models.dart';
import '../data/notifications.dart';
import '../data/session.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'consent_screen.dart';
import 'official_screen.dart';
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
  /// Anahtarın durumu tercihten okunuyor, varsayılan kapalı: bildirim
  /// göndermek izin ister, izinsiz açık göstermek yalan olurdu.
  bool _monthlyPush = false;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    _readReminder();
  }

  Future<void> _readReminder() async {
    final on = await context.read<MonthlyReminder>().isOn();
    if (mounted) setState(() => _monthlyPush = on);
  }

  Future<void> _toggleReminder(bool v) async {
    if (_pushBusy) return;
    setState(() => _pushBusy = true);
    final reminder = context.read<MonthlyReminder>();
    try {
      if (!v) {
        await reminder.disable();
        if (mounted) setState(() => _monthlyPush = false);
        return;
      }
      final r = await reminder.enable();
      if (!mounted) return;
      setState(() => _monthlyPush = r == ReminderResult.on);
      if (r == ReminderResult.denied) {
        // Reddedilen izin uygulama içinden yeniden sorulamıyor; tek yol
        // Ayarlar. Anahtarı açık bırakmak yerine ne olduğu söyleniyor.
        _toast(context, 'Bildirim izni kapalı — Ayarlar > Sepet > Bildirimler');
      }
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final s = switch (auth) {
          AuthSignedIn(:final session) => session,
          _ => null,
        };
        return ScreenFrame(
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
                  DataView<IndexCubit, IndexHome>(
                    builder: (context, home) => PaperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < home.snapshot.official.length;
                            i++
                          ) ...[
                            if (i > 0) const Hairline(),
                            _SourceRow(source: home.snapshot.official[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Resmî ölçüm senin sayının yanında duruyor. Uygulama onu '
                    'doğrulamıyor ya da yorumlamıyor — yalnızca referans '
                    'çizgisi.',
                    style: TextStyle(fontSize: 11, height: 1.5, color: C.muted),
                  ),
                  const SizedBox(height: 8),
                  _ActionRow(
                    label: 'Resmî verileri gir',
                    hint: 'Elle',
                    onTap: () =>
                        Navigator.of(context).push(OfficialScreen.route()),
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
                          key: const Key('monthly-reminder'),
                          value: _monthlyPush,
                          activeThumbColor: C.card,
                          activeTrackColor: C.ink,
                          onChanged: _pushBusy ? null : _toggleReminder,
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
                  if (s != null) ...[
                    _ActionRow(
                      key: const Key('clear-receipts'),
                      label: 'Fişleri sil',
                      hint: 'Hesap kalır',
                      danger: true,
                      onTap: () => _confirmClearReceipts(context),
                    ),
                    _ActionRow(
                      key: const Key('delete-account'),
                      label: 'Hesabı sil',
                      hint: '',
                      danger: true,
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (s != null)
                    PrimaryButton(
                      label: 'Çıkış yap',
                      dark: false,
                      onTap: () => context.read<AuthCubit>().signOut(),
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
        );
      },
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

  /// Ortak onay penceresi. [onConfirm] yalnızca kullanıcı "Sil" derse çalışır.
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: Text(title, style: T.title),
        content: Text(
          body,
          style: const TextStyle(fontSize: 12.5, height: 1.5, color: C.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: C.hot)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Fişleri siler, hesabı bırakır. Demo veriden gerçek kullanıma geçiş yolu.
  Future<void> _confirmClearReceipts(BuildContext context) async {
    final repo = context.read<Repository>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _confirm(
      context,
      title: 'Fişleri sil',
      body:
          'Bütün fişlerin ve endeks geçmişin silinir. Hesabın, izinlerin ve '
          'öğrenilmiş ürün eşleşmelerin kalır — endeks bir sonraki fişinden '
          'itibaren sıfırdan kurulur. Bu işlem geri alınamaz.',
    );
    if (!ok) return;

    try {
      final n = await repo.clearReceipts();
      if (context.mounted) refreshUserData(context);
      messenger.showSnackBar(_snack('$n fiş silindi'));
    } on ApiException catch (e) {
      messenger.showSnackBar(_snack(e.message));
    }
  }

  /// Hesabı gerçekten siler.
  ///
  /// Eskiden bu düğme sunucuya hiç istek atmıyor, yalnızca oturumu
  /// kapatıyordu — oysa metin "kalıcı olarak silinir" diyordu. Veri
  /// sunucuda duruyordu.
  Future<void> _confirmDelete(BuildContext context) async {
    // Onay penceresi bir async boşluk açıyor; context'e ondan sonra
    // dokunulmasın diye ihtiyaç duyulanlar önden alınıyor.
    final auth = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _confirm(
      context,
      title: 'Hesabı sil',
      body:
          'Tüm fişlerin ve endeks geçmişin kalıcı olarak silinir. '
          'Bu işlem geri alınamaz.',
    );
    if (!ok) return;

    try {
      await auth.deleteAccount();
    } on ApiException catch (e) {
      messenger.showSnackBar(_snack(e.message));
    }
  }

  SnackBar _snack(String text) => SnackBar(
    backgroundColor: C.ink,
    behavior: SnackBarBehavior.floating,
    content: Text(text, style: const TextStyle(fontSize: 12.5, color: C.card)),
  );
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
                    session.email ?? session.provider.label,
                    style: T.label.copyWith(fontSize: 10, letterSpacing: .3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DataView<ReceiptsCubit, List<Receipt>>(
          builder: (context, receipts) => PaperCard(
            child: Row(
              children: [
                _Metric('FİŞ', '${receipts.length}'),
                _Metric(
                  'ÜRÜN',
                  '${receipts.fold<int>(0, (a, r) => a + r.itemCount)}',
                ),
                _Metric(
                  'EŞLEŞME',
                  '${receipts.fold<int>(0, (a, r) => a + r.pendingCount)}',
                ),
              ],
            ),
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
                  source.value == null ? 'VERİ BEKLENİYOR' : 'SON 12 AY',
                  style: T.label.copyWith(fontSize: 8.5),
                ),
              ],
            ),
          ),
          Text(
            source.value == null ? '—' : Fmt.pct1(source.value!),
            style: T.num12.copyWith(
              color: source.value == null ? C.muted : C.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
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
