import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/official_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/data_view.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// Karşılaştırma serilerinin elle girildiği ekran.
///
/// Neden elle: TÜİK'in kendi veri portalı otomatik erişimde yönlendirmeye
/// düşüyor, MEDAS oturum tabanlı bir arayüz. Resmî ve makine okunur kanal
/// TCMB'nin EVDS'i ve ücretsiz bir API anahtarı istiyor; anahtar
/// tanımlanana kadar tek yol burası.
///
/// Uydurmak seçenek değildi: uygulamanın bütün iddiası ölçülen sayıların
/// gerçek olması. Ayda bir sayı — elle girmek makul bir bedel.
class OfficialScreen extends StatelessWidget {
  const OfficialScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    builder: (context) => BlocProvider(
      create: (_) => OfficialCubit(context.read<Repository>())..load(),
      child: const OfficialScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Resmî veriler',
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.back, size: 17, color: C.ink, stroke: 1.6),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DataView<OfficialCubit, List<OfficialSeries>>(
            builder: (context, series) => Padding(
              padding: kGutter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'TÜİK sayısını henüz otomatik çekmiyoruz. Uydurmak '
                    'yerine boş bırakıyoruz — buraya sen giriyorsun.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: C.muted),
                  ),
                  const SizedBox(height: 16),
                  _RefreshRow(),
                  const SizedBox(height: 20),
                  for (final s in series) ...[
                    _SeriesBlock(series: s),
                    const SizedBox(height: 22),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// TCMB EVDS'ten çekme satırı.
///
/// Elle giriş yolu kalkmadı: anahtar sunucuda tanımlı değilse ya da TCMB'ye
/// ulaşılamıyorsa kullanıcı yine kendi girebiliyor. İki yol birbirini
/// dışlamıyor.
class _RefreshRow extends StatefulWidget {
  @override
  State<_RefreshRow> createState() => _RefreshRowState();
}

class _RefreshRowState extends State<_RefreshRow> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final cubit = context.read<OfficialCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await cubit.refreshFromSource();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: C.ink,
          behavior: SnackBarBehavior.floating,
          content: Text(
            n == 0 ? 'Yeni ay yok' : '$n ay güncellendi',
            style: const TextStyle(fontSize: 12.5, color: C.card),
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: _run,
      child: PaperCard(
        padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TCMB EVDS’ten çek', style: T.title),
                  SizedBox(height: 3),
                  Text(
                    'TÜİK TÜFE’nin resmî dağıtım kanalı',
                    style: TextStyle(fontSize: 11, color: C.muted),
                  ),
                ],
              ),
            ),
            if (_busy)
              const CupertinoLikeSpinner()
            else
              const LineIcon(Glyph.chevron, size: 15, color: C.muted),
          ],
        ),
      ),
    );
  }
}

class _SeriesBlock extends StatelessWidget {
  const _SeriesBlock({required this.series});

  final OfficialSeries series;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(series.title, style: T.title)),
            Pressable(
              onTap: () => _openForm(context, series),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: C.ink,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'AY EKLE',
                  style: T.label.copyWith(fontSize: 9.5, color: C.card),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          series.official ? 'Resmî kurum' : 'Bağımsız ölçüm',
          style: T.label.copyWith(fontSize: 9, letterSpacing: .6),
        ),
        const SizedBox(height: 8),
        if (series.entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Henüz ay girilmedi.',
              style: TextStyle(fontSize: 12, color: C.muted),
            ),
          )
        else
          for (final e in series.entries)
            Pressable(
              onTap: () => _openForm(context, series, existing: e),
              child: LedgerRow(
                name: Fmt.monthLong(e.month),
                sub: '${e.month.year}',
                amount: Fmt.signedPct1(e.yoyPct),
                amountColor: e.yoyPct >= 0 ? C.hot : C.ref,
              ),
            ),
      ],
    );
  }

  Future<void> _openForm(
    BuildContext context,
    OfficialSeries series, {
    OfficialEntry? existing,
  }) async {
    // Cubit'i önden al: alt sayfa bir async boşluk açıyor.
    final cubit = context.read<OfficialCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<_FormResult>(
      context: context,
      backgroundColor: C.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _EntryForm(series: series, existing: existing),
    );
    if (result == null) return;

    try {
      if (result.delete) {
        await cubit.remove(code: series.code, month: result.month);
        messenger.showSnackBar(
          _snack('${Fmt.monthLong(result.month)} silindi'),
        );
      } else {
        await cubit.save(
          code: series.code,
          month: result.month,
          yoyPct: result.yoyPct!,
        );
        messenger.showSnackBar(
          _snack('${Fmt.monthLong(result.month)} kaydedildi'),
        );
      }
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

class _FormResult {
  const _FormResult({required this.month, this.yoyPct, this.delete = false});
  final DateTime month;
  final double? yoyPct;
  final bool delete;
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.series, this.existing});

  final OfficialSeries series;
  final OfficialEntry? existing;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  late DateTime _month;
  late final TextEditingController _value;
  String? _error;

  /// Son 24 ay. İleri tarih yok: açıklanmamış bir ay girilemez.
  late final List<DateTime> _months = List.generate(24, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month - i);
  });

  @override
  void initState() {
    super.initState();
    _month = widget.existing?.month ?? _months.first;
    _value = TextEditingController(
      text: widget.existing == null
          ? ''
          : Fmt.dec1(widget.existing!.yoyPct).replaceAll('−', '-'),
    );
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    // Girdi BİLEREK filtrelenmiyor. Bir ara harfleri anında eleyen bir
    // biçimlendirici koymuştum; klavye virgüli bozunca "58,4" sessizce
    // "584" oluyordu ve geçerli bir sayı olduğu için doğrulamadan geçiyordu.
    // Görünür bir hatayı sessiz bir veri bozulmasına çevirmek, sayıların
    // doğruluğu üzerine kurulu bir uygulamada kabul edilebilir değil.
    // Ayıklamak yerine reddetmek doğru olan.
    //
    // Türkçe klavyede ondalık ayracı virgül; nokta da kabul ediliyor.
    final text = _value.text.trim().replaceAll(',', '.').replaceAll('−', '-');
    final parsed = double.tryParse(text);
    if (parsed == null) {
      setState(() => _error = 'Sayı gir, örneğin 33,5');
      return;
    }
    if (parsed < -100 || parsed > 1000) {
      setState(() => _error = '−100 ile 1000 arasında olmalı');
      return;
    }
    Navigator.of(context).pop(_FormResult(month: _month, yoyPct: parsed));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.series.title, style: T.title),
          const SizedBox(height: 2),
          Text(
            'Yıllık değişim, kaynağın açıkladığı gibi.',
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
          const SizedBox(height: 16),
          const Lbl('AY'),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: C.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<DateTime>(
                value: _months.firstWhere(
                  (m) => m.year == _month.year && m.month == _month.month,
                  orElse: () => _months.first,
                ),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                // Düzeltirken ay değişmesin: kayıt aya bağlı.
                onChanged: editing
                    ? null
                    : (m) => setState(() => _month = m ?? _month),
                items: [
                  for (final m in _months)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${Fmt.monthLong(m)} ${m.year}',
                        style: T.body,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Lbl('YILLIK DEĞİŞİM (%)'),
          const SizedBox(height: 6),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            style: const TextStyle(
              fontFamily: F.mono,
              fontFamilyFallback: F.monoFallback,
              fontSize: 17,
              color: C.ink,
            ),
            decoration: InputDecoration(
              hintText: '33,5',
              errorText: _error,
              filled: true,
              fillColor: C.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: C.line),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Kaydet', onTap: _submit),
          if (editing) ...[
            const SizedBox(height: 8),
            Center(
              child: Pressable(
                onTap: () =>
                    Navigator.of(context)
                        .pop(_FormResult(month: _month, delete: true)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Bu ayı sil',
                    style: T.label.copyWith(fontSize: 10, color: C.hot),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
