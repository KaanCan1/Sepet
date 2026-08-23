import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository.dart';
import '../data/api.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../data/receipt_parser.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// OCR çıktısının kullanıcı tarafından onaylandığı ekran.
///
/// OCR yanılır; yanlış okunan bir tutar endeksi sessizce bozar. Bu yüzden
/// kaydetmeden önce satırlar düzeltilebilir oluyor ve fişteki TOPLAM ile
/// satırların toplamı karşılaştırılıyor.
class DraftReceiptScreen extends StatefulWidget {
  const DraftReceiptScreen({super.key, required this.parsed});

  final ParsedReceipt parsed;

  static Route<bool> route(ParsedReceipt parsed) => CupertinoPageRoute<bool>(
    builder: (_) => DraftReceiptScreen(parsed: parsed),
  );

  @override
  State<DraftReceiptScreen> createState() => _DraftReceiptScreenState();
}

class _DraftReceiptScreenState extends State<DraftReceiptScreen> {
  late final List<ParsedLine> _lines = List.of(widget.parsed.lines);
  late DateTime _date = widget.parsed.date ?? DateTime.now();
  Merchant? _merchant;
  List<Merchant> _merchants = const [];
  bool _saving = false;
  String? _error;
  bool _loaded = false;

  double get _sum => _lines.fold(0, (a, l) => a + l.amount);

  /// Fişte yazan toplamla satırların toplamı arasındaki fark. Küçük bir
  /// yuvarlama payı bırakılıyor.
  double? get _gap {
    final total = widget.parsed.total;
    if (total == null) return null;
    final diff = _sum - total;
    return diff.abs() <= 0.05 ? null : diff;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    try {
      final list = await context.read<Repository>().merchants();
      if (!mounted) return;
      setState(() {
        _merchants = list;
        // OCR zinciri tanıdıysa önceden seç.
        final code = widget.parsed.merchantCode;
        _merchant = code == null
            ? null
            : list.where((m) => m.chainCode == code).firstOrNull;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickMerchant() async {
    final picked = await showModalBottomSheet<Merchant>(
      context: context,
      backgroundColor: const Color(0x00000000),
      barrierColor: const Color(0x3316181A),
      builder: (_) => _MerchantSheet(merchants: _merchants),
    );
    if (picked != null && mounted) setState(() => _merchant = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final result = await showModalBottomSheet<ParsedLine?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      barrierColor: const Color(0x3316181A),
      builder: (_) => _LineSheet(line: line),
    );
    if (!mounted || result == null) return;
    setState(() => _lines[index] = result);
  }

  Future<void> _save() async {
    if (_saving || _merchant == null || _lines.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await context.read<Repository>().createReceipt(
        merchantId: _merchant!.id,
        purchasedAt: _date,
        lines: [
          for (final l in _lines)
            (raw: l.raw, quantity: l.quantity, amount: l.amount),
        ],
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = _gap;
    final ready = _merchant != null && _lines.isNotEmpty && !_saving;

    return ScreenFrame(
      title: 'Okunan fiş',
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(false),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(Glyph.back, size: 17, color: C.ink, stroke: 1.6),
        ),
      ),
      footer: PrimaryButton(
        label: _saving
            ? 'Kaydediliyor…'
            : (_merchant == null ? 'Önce market seç' : 'Sepete ekle'),
        onTap: ready ? _save : null,
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'MARKET',
                      value: _merchant?.name ?? 'Seç',
                      muted: _merchant == null,
                      onTap: _merchants.isEmpty ? null : _pickMerchant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      label: 'TARİH',
                      value: '${Fmt.dayMonth(_date)} ${_date.year}',
                      onTap: _pickDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Lbl('${_lines.length} SATIR OKUNDU'),
              const SizedBox(height: 8),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _lines.length; i++) ...[
                      if (i > 0) const Hairline(),
                      _DraftRow(
                        line: _lines[i],
                        onTap: () => _editLine(i),
                        onRemove: () => setState(() => _lines.removeAt(i)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PaperCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Satırların toplamı',
                        style: TextStyle(fontSize: 11.5, color: C.muted),
                      ),
                    ),
                    Text(Fmt.money(_sum), style: T.num12),
                  ],
                ),
              ),
              if (gap != null) ...[
                const SizedBox(height: 10),
                _Warning(
                  text:
                      'Fişte TOPLAM ${Fmt.money(widget.parsed.total!)} yazıyor, '
                      'satırlar ${Fmt.money(_sum)} tutuyor. '
                      '${gap < 0 ? 'Bir satır okunamamış olabilir.' : 'Fazladan bir satır okunmuş olabilir.'} '
                      'Düzeltmeden kaydedersen endeks bu fişten yanlış beslenir.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                _Warning(text: _error!),
              ],
              const SizedBox(height: 12),
              const Text(
                'Satıra dokunarak adını ve tutarını düzeltebilir, yanlış '
                'okunanı silebilirsin. Ürün eşleştirmesi kaydettikten sonra '
                'soruluyor.',
                style: TextStyle(fontSize: 11, height: 1.5, color: C.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: PaperCard(
      padding: const EdgeInsets.fromLTRB(13, 10, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Lbl(label),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: muted ? C.muted : C.ink,
                  ),
                ),
              ),
              const LineIcon(Glyph.chevron, size: 13, color: C.muted),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.line,
    required this.onTap,
    required this.onRemove,
  });

  final ParsedLine line;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    color: C.card,
    child: Row(
      children: [
        Expanded(
          child: Pressable(
            scale: .99,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 11, 8, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.raw, style: T.num11.copyWith(fontSize: 11)),
                        if (line.quantity != 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${Fmt.quantity(line.quantity)} × '
                            '${Fmt.money(line.amount / line.quantity)}',
                            style: T.raw,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(Fmt.money(line.amount), style: T.num11),
                ],
              ),
            ),
          ),
        ),
        Pressable(
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 12, 12),
            child: LineIcon(Glyph.close, size: 14, color: C.muted),
          ),
        ),
      ],
    ),
  );
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
    decoration: BoxDecoration(
      color: C.hotBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11.5, height: 1.5, color: C.hot),
    ),
  );
}

/// Market seçimi.
class _MerchantSheet extends StatelessWidget {
  const _MerchantSheet({required this.merchants});

  final List<Merchant> merchants;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: GlassBar(
        borderSide: GlassEdge.none,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + pad),
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
              const Lbl('MARKET'),
              const SizedBox(height: 8),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < merchants.length; i++) ...[
                      if (i > 0) const Hairline(),
                      Pressable(
                        scale: .99,
                        onTap: () => Navigator.of(context).pop(merchants[i]),
                        child: Container(
                          color: C.card,
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
                          child: Text(
                            merchants[i].name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: C.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek satırın adını ve tutarını düzeltme.
class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.line});
  final ParsedLine line;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late final _name = TextEditingController(text: widget.line.raw);
  late final _amount = TextEditingController(
    text: Fmt.money(widget.line.amount),
  );

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = ReceiptParser.parseAmount(_amount.text.trim());
    final name = _name.text.trim();
    if (amount == null || amount <= 0 || name.isEmpty) return;
    Navigator.of(context).pop(
      ParsedLine(
        raw: name,
        amount: amount,
        quantity: widget.line.quantity,
        unitPrice: widget.line.unitPrice,
      ),
    );
  }

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
              const SizedBox(height: 6),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  style: T.num12.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Lbl('TUTAR'),
              const SizedBox(height: 6),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '0,00',
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  style: T.num12.copyWith(fontSize: 13),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Tamam', onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
