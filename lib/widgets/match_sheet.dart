import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository.dart';
import '../data/api.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'glass.dart';
import 'icons.dart';

/// "eşleşme?" sorusu — buzlu cam alt sayfa.
///
/// Sayfa iki biçimde açılıyor ve hangisinin açılacağına sunucu karar veriyor:
///
/// - **Gramaj sorusu.** Marka ve ürün çözülmüş, geriye yalnızca boy kalmış.
///   Arama kutusu yok, klavye yok; sadece boy seçenekleri ve her birinin
///   yanında o seçim yapılırsa çıkacak birim fiyat. Fiş gramajı basmıyor ve
///   endeks birim fiyat üzerinden hesaplandığı için bu ekranın tek işi
///   endeksi yanlış sayıdan korumak.
/// - **Ürün sorusu.** Sıralı adaylar, altında arama. Doğru aday genelde
///   zaten ilk sırada.
///
/// Seçilen ürün hem satırı düzeltiyor hem de bu market + ham metin için
/// alias'a yazılıyor, böylece aynı fiş formatı bir daha sorulmuyor.
class MatchSheet extends StatefulWidget {
  const MatchSheet({super.key, required this.line});

  final ReceiptLine line;

  /// Seçilen kanonik ürünün kimliğini döndürür.
  static Future<String?> show(BuildContext context, ReceiptLine line) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0x00000000),
        barrierColor: const Color(0x3316181A),
        builder: (_) => MatchSheet(line: line),
      );

  @override
  State<MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<MatchSheet> {
  late final TextEditingController _controller = TextEditingController();

  MatchSuggestion _suggestion = MatchSuggestion.empty;
  List<ProductRef> _results = const [];

  /// Kullanıcı arama kutusuna dokunduğu an öneri modundan çıkılıyor.
  bool _searching = false;

  /// Katalogda olmayan bir boy giriliyor.
  bool _customSize = false;
  final _sizeInput = TextEditingController();
  String _customUnit = 'g';
  bool _saving = false;
  bool _loading = true;
  String? _error;
  bool _started = false;

  bool get _sizeOnly => _suggestion.sizeAmbiguous && !_searching;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState'te InheritedWidget'a bakılamıyor; ilk çağrı buradan.
    if (_started) return;
    _started = true;
    _suggest();
  }

  @override
  void dispose() {
    _controller.dispose();
    _sizeInput.dispose();
    super.dispose();
  }

  /// Girilen boyun kanonik birim cinsinden değeri.
  double? get _customValue {
    final raw = double.tryParse(_sizeInput.text.trim().replaceAll(',', '.'));
    if (raw == null || raw <= 0) return null;
    return SizeLabel.toCanonical(raw, _customUnit);
  }

  /// Girilen boy seçilirse endekse girecek birim fiyat.
  String get _customUnitPrice {
    final v = _customValue;
    if (v == null || v <= 0) return '—';
    return Fmt.money(widget.line.amount / (widget.line.quantity * v));
  }

  Future<void> _saveCustomSize(ProductRef base) async {
    final raw = double.tryParse(_sizeInput.text.trim().replaceAll(',', '.'));
    final value = _customValue;
    if (raw == null || value == null || base.groupId == null) return;

    setState(() => _saving = true);
    final repo = context.read<Repository>();
    try {
      final created = await repo.addCatalogSize(
        groupId: base.groupId!,
        brandId: base.brandId,
        sizeLabel: SizeLabel.build(raw, _customUnit),
        sizeValue: value,
      );
      if (mounted) Navigator.of(context).pop(created.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _suggest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<Repository>();
    try {
      final s = await repo.suggestMatches(widget.line.raw);
      if (mounted) setState(() => _suggestion = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _loading = true;
      _error = null;
    });
    final repo = context.read<Repository>();
    try {
      final rows = await repo.searchCatalog(q);
      if (mounted) setState(() => _results = rows);
    } on ApiException catch (e) {
      // Arama başarısızsa "sonuç yok" demek yanlış olur — ikisi ayrı durum.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bu boy seçilirse endekse girecek birim fiyat.
  ///
  /// Kullanıcının gördüğü tek doğrulama bu: 3 kg'lık yoğurdu 1 kg sanmak
  /// kilo fiyatını üçe katlar ve o ay sahte bir zam olarak endekse girer.
  ///
  /// Hesap sunucudaki size_value ile: paket içeriği kanonik birim cinsinden
  /// zaten orada duruyor. Etiketten sayı ayrıştırmak yanlış olurdu —
  /// "400 g" etiketinin kanonik değeri 400 değil 0,4.
  String _unitPrice(ProductRef p) {
    final size = p.sizeValue;
    if (size == null || size <= 0) return '';
    return Fmt.money(widget.line.amount / (widget.line.quantity * size));
  }

  /// Birim fiyatın etiketi grubun kanonik biriminden geliyor: kilogram
  /// grubunda "kg fiyatı", paket 400 g olsa bile.
  static String _unitLabel(String? canonicalUnit) => switch (canonicalUnit) {
    'kilogram' => 'kg',
    'litre' => 'litre',
    _ => 'adet',
  };

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final pad = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: GlassBar(
        borderSide: GlassEdge.none,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + pad + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Lbl('FİŞTEKİ SATIR'),
              const SizedBox(height: 5),
              Text(widget.line.rawLine, style: T.num12),
              const SizedBox(height: 16),
              if (_sizeOnly) ..._sizeMode() else ..._productMode(),
            ],
          ),
        ),
      ),
    );
  }

  /// Gramaj sorusunda gösterilecek boylar.
  ///
  /// Aday listesi daha geniş geliyor — başka markaların ve grupların
  /// kalemleri de var. Boy sorusunda onları göstermek ekranı bozuyor:
  /// "Sütaş Yoğurt 1 kg" ile "Migros Yoğurt 1 kg" aynı satır gibi
  /// görünüyor ve ekranın kaldırmak için var olduğu belirsizliği
  /// yeniden üretiyor. Yalnızca aynı marka ve grubun boyları kalıyor.
  List<ProductRef> get _sizeOptions {
    // Sunucu boy sorulacaksa listeyi tam ve sıralı gönderiyor.
    if (_suggestion.sizes.isNotEmpty) return _suggestion.sizes;

    final first = _suggestion.candidates.first;
    final same = _suggestion.candidates
        .where((c) => c.groupName == first.groupName && c.brand == first.brand)
        .toList();
    same.sort((a, b) => (a.sizeValue ?? 0).compareTo(b.sizeValue ?? 0));
    return same;
  }

  // ── Gramaj sorusu ───────────────────────────────────────────────
  List<Widget> _sizeMode() {
    final first = _suggestion.candidates.first;
    final options = _sizeOptions;
    return [
      Row(
        children: [
          BrandChip(first.monogram),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              first.name,
              style: const TextStyle(fontSize: 13.5, color: C.ink),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Ödenen ${Fmt.money(widget.line.amount)}'
        '${widget.line.quantity == 1 ? '' : ' · ${ReceiptLine.qtyLabel(widget.line.quantity)} adet'}',
        style: T.raw,
      ),
      const SizedBox(height: 16),
      const Lbl('HANGİ BOY?'),
      const SizedBox(height: 8),
      PaperCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const Hairline(),
              _SizeOption(
                product: options[i],
                unitPrice: _unitPrice(options[i]),
                unitLabel: _unitLabel(options[i].unit),
                onTap: () => Navigator.of(context).pop(options[i].id),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (_customSize)
        _CustomSizeEditor(
          controller: _sizeInput,
          units: SizeLabel.unitsFor(first.unit ?? 'kilogram'),
          unit: _customUnit,
          unitPrice: _customUnitPrice,
          unitLabel: _unitLabel(first.unit),
          saving: _saving,
          onUnit: (u) => setState(() => _customUnit = u),
          onChanged: () => setState(() {}),
          onSave: () => _saveCustomSize(first),
        )
      else
        Pressable(
          onTap: () => setState(() {
            _customSize = true;
            _customUnit = SizeLabel.unitsFor(first.unit ?? 'kilogram').first;
          }),
          child: const Text(
            'Listede yok, gramajı kendim gireyim',
            style: TextStyle(fontSize: 12.5, color: C.ref),
          ),
        ),
      const SizedBox(height: 10),
      const Text(
        'Fiş gramajı basmıyor. Seçtiğin boy endeksin birim fiyatını '
        'belirliyor — yanlış seçim sessizce yanlış enflasyon üretir.',
        style: TextStyle(fontSize: 11, height: 1.4, color: C.muted),
      ),
      const SizedBox(height: 10),
      Pressable(
        onTap: () => setState(() => _searching = true),
        child: const Text(
          'Bu ürün değil',
          style: TextStyle(fontSize: 12, color: C.ref),
        ),
      ),
    ];
  }

  // ── Ürün sorusu ─────────────────────────────────────────────────
  List<Widget> _productMode() {
    final rows = _searching ? _results : _suggestion.candidates;
    return [
      Lbl(_searching ? 'HANGİ ÜRÜN?' : 'ÖNERİLENLER'),
      const SizedBox(height: 8),
      if (!_searching && rows.isNotEmpty) ...[
        PaperCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(),
                _CandidateRow(
                  product: rows[i],
                  onTap: () => Navigator.of(context).pop(rows[i].id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: TextField(
          controller: _controller,
          autofocus: false,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Katalogda ara',
            hintStyle: TextStyle(fontSize: 13.5, color: C.muted),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 13),
          ),
          style: const TextStyle(fontSize: 13.5, color: C.ink),
          onChanged: _search,
        ),
      ),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: _buildSearchBody(rows),
      ),
      const SizedBox(height: 10),
      const Text(
        'Seçimin bu markete ait fiş formatı için kaydedilir.',
        style: TextStyle(fontSize: 11, color: C.muted),
      ),
    ];
  }

  Widget _buildSearchBody(List<ProductRef> rows) {
    if (_loading && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: C.muted),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          _error!,
          style: const TextStyle(fontSize: 12, color: C.hot),
        ),
      );
    }
    if (!_searching) return const SizedBox.shrink();
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Katalogda eşleşen ürün yok. Farklı bir kelime dene.',
          style: TextStyle(fontSize: 12, color: C.muted),
        ),
      );
    }
    return PaperCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Hairline(),
        itemBuilder: (context, i) => _CandidateRow(
          product: rows[i],
          onTap: () => Navigator.of(context).pop(rows[i].id),
        ),
      ),
    );
  }
}

/// Tek boy seçeneği. Sağda o seçim yapılırsa endekse girecek birim fiyat.
class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.product,
    required this.unitPrice,
    required this.unitLabel,
    required this.onTap,
  });

  final ProductRef product;
  final String unitPrice;
  final String unitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: .99,
      onTap: onTap,
      child: Container(
        color: C.card,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                product.sizeLabel,
                style: const TextStyle(
                  fontFamily: F.display,
                  fontFamilyFallback: F.displayFallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: C.ink,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$unitLabel fiyatı', style: T.raw),
                const SizedBox(height: 2),
                Text(unitPrice, style: T.num12),
              ],
            ),
            const SizedBox(width: 8),
            const LineIcon(Glyph.chevron, size: 13, color: C.muted),
          ],
        ),
      ),
    );
  }
}

/// Aday satırı: marka rozeti, ad, güven çubuğu.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.product, required this.onTap});

  final ProductRef product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = product.score;
    return Pressable(
      scale: .99,
      onTap: onTap,
      child: Container(
        color: C.card,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          children: [
            BrandChip(product.monogram, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 12.5, color: C.ink),
                  ),
                  if (product.sizeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(product.sizeLabel, style: T.raw),
                  ],
                ],
              ),
            ),
            if (score != null) ...[
              const SizedBox(width: 8),
              _ConfidenceBar(score),
            ],
            const SizedBox(width: 8),
            const LineIcon(Glyph.chevron, size: 13, color: C.muted),
          ],
        ),
      ),
    );
  }
}

/// Sunucunun güven puanı. Sayı değil çubuk: kullanıcının 0,71'i
/// yorumlaması beklenmiyor, ilk adayın açık ara önde olduğunu görmesi yeterli.
class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar(this.score);

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 3,
      decoration: BoxDecoration(
        color: C.line,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: score.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(
            color: C.ref,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Katalogda olmayan boyu girme alanı.
///
/// Sayı ve birim ayrı: fiş "400 g" da yazabilir "0,4 kg" da, kullanıcı hangisi
/// kolayına geliyorsa onu giriyor. Sağda, yazarken güncellenen birim fiyat —
/// bu ekranın tek doğrulaması o.
class _CustomSizeEditor extends StatelessWidget {
  const _CustomSizeEditor({
    required this.controller,
    required this.units,
    required this.unit,
    required this.unitPrice,
    required this.unitLabel,
    required this.saving,
    required this.onUnit,
    required this.onChanged,
    required this.onSave,
  });

  final TextEditingController controller;
  final List<String> units;
  final String unit;
  final String unitPrice;
  final String unitLabel;
  final bool saving;
  final ValueChanged<String> onUnit;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ready = unitPrice != '—' && !saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Lbl('PAKET BOYU'),
        const SizedBox(height: 8),
        PaperCard(
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '400',
                        hintStyle: TextStyle(fontSize: 15, color: C.grey),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                      style: const TextStyle(
                        fontFamily: F.mono,
                        fontFamilyFallback: F.monoFallback,
                        fontSize: 15,
                        color: C.ink,
                      ),
                      onChanged: (_) => onChanged(),
                      onSubmitted: (_) => ready ? onSave() : null,
                    ),
                  ),
                  for (final u in units) ...[
                    const SizedBox(width: 6),
                    Pressable(
                      onTap: () => onUnit(u),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: u == unit ? C.ink : null,
                          borderRadius: BorderRadius.circular(999),
                          border: u == unit ? null : Border.all(color: C.line),
                        ),
                        child: Text(
                          u,
                          style: TextStyle(
                            fontFamily: F.mono,
                            fontFamilyFallback: F.monoFallback,
                            fontSize: 11,
                            color: u == unit ? C.card : C.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Hairline(),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text('$unitLabel fiyatı', style: T.raw),
                  const Spacer(),
                  Text(unitPrice, style: T.num12),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Pressable(
          onTap: ready ? onSave : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ready ? C.ink : C.line,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              saving ? 'Ekleniyor…' : 'Bu boyu ekle',
              style: TextStyle(fontSize: 13, color: ready ? C.card : C.muted),
            ),
          ),
        ),
      ],
    );
  }
}
