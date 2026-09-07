import 'package:flutter/material.dart';

import '../data/fmt.dart';
import '../data/models.dart';
import '../data/receipt_parser.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'glass.dart';
import 'screen_frame.dart';

/// Kaydedilmiş bir satıra dokununca çıkan düzeltme sayfasının sonucu.
sealed class LineEdit {
  const LineEdit();
}

/// Tutar ve/veya miktar değişti.
class LineAmounts extends LineEdit {
  const LineAmounts({required this.amount, required this.quantity});
  final double amount;
  final double quantity;
}

/// Kullanıcı ürünü değiştirmek istedi; eşleştirme sayfası açılacak.
class LineRematch extends LineEdit {
  const LineRematch();
}

/// Kaydedilmiş fiş satırını düzeltme sayfası.
///
/// Taslak ekranında satır düzeltilebiliyordu ama fiş kaydedilince o imkân
/// kayboluyordu: yalnızca eşleşmemiş satırlara dokunulabiliyordu. OCR tutarı
/// yanlış okuduysa ya da otomatik eşleşme yanlış ürüne bağladıysa tek çare
/// fişi silip yeniden eklemekti — oysa yanlış bir satır endeksi sessizce
/// bozuyor ve uygulamanın bütün iddiası o sayının kullanıcının kendi
/// fişinden gelmesi.
///
/// Ham metin düzenlenmiyor: fişte ne yazıyorsa o. Değişebilen, o metnin
/// hangi ürüne, hangi tutara ve kaç birime karşılık geldiği.
class LineSheet extends StatefulWidget {
  const LineSheet({super.key, required this.line});

  final ReceiptLine line;

  static Future<LineEdit?> show(BuildContext context, ReceiptLine line) =>
      showModalBottomSheet<LineEdit>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0x00000000),
        barrierColor: const Color(0x3316181A),
        builder: (_) => LineSheet(line: line),
      );

  @override
  State<LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<LineSheet> {
  // Fmt.money ile parseAmount birbirinin tersi: binlik ayırıcı nokta,
  // ondalık virgül ve tam iki hane. Alan da o biçimde açılıyor ki
  // kullanıcı dokunmadan kaydetse bile aynı sayı geri gitsin.
  late final _amount = TextEditingController(
    text: Fmt.money(widget.line.amount),
  );
  late final _quantity = TextEditingController(
    text: Fmt.quantity(widget.line.quantity),
  );

  @override
  void dispose() {
    _amount.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _kaydet() {
    // Miktarın kendi ayrıştırıcısı var: parseAmount tam iki ondalık
    // istiyor ve "3" gibi bir miktarı reddediyor.
    final tutar = ReceiptParser.parseAmount(_amount.text.trim());
    final miktar = ReceiptParser.parseQuantity(_quantity.text.trim());
    // Miktar sıfır olamaz: birim fiyat ona bölünüyor. Tutar sıfır olabilir
    // (bedava kalem); sunucu onu gözlem saymıyor.
    if (tutar == null || tutar < 0 || miktar == null || miktar <= 0) return;
    Navigator.of(context).pop(LineAmounts(amount: tutar, quantity: miktar));
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final pad = MediaQuery.paddingOf(context).bottom;
    final c = context.c;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: GlassBar(
        borderSide: GlassEdge.none,
        child: SingleChildScrollView(
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
                    color: c.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Lbl('FİŞTEKİ SATIR'),
              const SizedBox(height: 5),
              // Salt okunur: fişin kendi metni. Düzeltilebilir olsaydı
              // fişle ekran arasındaki bağ kopardı.
              Text(widget.line.raw, style: T.raw.copyWith(fontSize: 12.5)),
              const SizedBox(height: 18),
              const Lbl('ÜRÜN'),
              const SizedBox(height: 4),
              ActionRow(
                label: widget.line.canonical ?? 'Eşleşmedi',
                hint: 'DEĞİŞTİR',
                onTap: () => Navigator.of(context).pop(const LineRematch()),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Alan(
                      label: 'TUTAR',
                      controller: _amount,
                      onSubmit: _kaydet,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Alan(
                      label: 'MİKTAR',
                      controller: _quantity,
                      onSubmit: _kaydet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'Kaydet', onTap: _kaydet),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alt çizgili sayı alanı — taslak ekranındakiyle aynı dil.
class _Alan extends StatelessWidget {
  const _Alan({
    required this.label,
    required this.controller,
    required this.onSubmit,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Lbl(label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.only(bottom: 9),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.line),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.ink),
            ),
          ),
          style: T.num12.copyWith(fontSize: 13),
          onSubmitted: (_) => onSubmit(),
        ),
      ],
    );
  }
}
