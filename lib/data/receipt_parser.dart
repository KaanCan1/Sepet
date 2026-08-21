/// Cihaz üstünde OCR'dan çıkan ham metni fiş satırlarına çevirir.
///
/// Tamamen saf Dart: kamera, ağ ya da eklenti yok. Türk market fişlerinin
/// biçimi burada tek yerde toplanıyor ve testlerle tutuluyor — OCR'ın kendisi
/// değişse de bu katman aynı kalır.
library;

/// Ayrıştırılmış tek satır.
class ParsedLine {
  const ParsedLine({
    required this.raw,
    required this.amount,
    this.quantity = 1,
    this.unitPrice,
  });

  /// Fişte yazan ürün adı, olduğu gibi.
  final String raw;

  /// Satırın toplam tutarı.
  final double amount;

  /// "3 X 38,90" satırından gelen adet ya da kilogram.
  final double quantity;

  /// Aynı satırdan gelen birim fiyat. Doğrulama için tutuluyor.
  final double? unitPrice;
}

/// Fişin tamamı.
class ParsedReceipt {
  const ParsedReceipt({
    required this.lines,
    this.merchantCode,
    this.date,
    this.total,
  });

  final List<ParsedLine> lines;

  /// Tanınan zincir kodu (BIM, A101 …). Tanınmadıysa kullanıcı seçecek.
  final String? merchantCode;

  final DateTime? date;

  /// Fişte yazan TOPLAM. Satırların toplamıyla karşılaştırmak için.
  final double? total;

  double get lineSum => lines.fold(0, (a, l) => a + l.amount);

  /// Satır toplamı fişteki toplamla tutuyor mu? OCR bir satırı kaçırdıysa
  /// ya da yanlış okuduysa burada yakalanıyor.
  bool get balances =>
      total == null || (lineSum - total!).abs() <= 0.05 * (total! + 1);
}

abstract final class ReceiptParser {
  /// Bilinen zincirler. Fişin üst kısmında aranıyor.
  static const _chains = <String, List<String>>{
    'BIM': ['BIM ', 'BIM BIRLESIK', 'BIM MAGAZALAR'],
    'A101': ['A101', 'A 101', 'YENI MAGAZACILIK'],
    'SOK': ['SOK MARKETLER', 'SOK MARKET', 'DIASA'],
    'MIGROS': ['MIGROS', 'MACROCENTER'],
    'CARREFOURSA': ['CARREFOUR', 'CARREFOURSA'],
  };

  /// Ürün olmayan satırlar. Bunlardan sonrası fişin özet kısmı.
  static const _stopWords = [
    'TOPLAM',
    'ARA TOPLAM',
    'TOPKDV',
    'KDV',
    'NAKIT',
    'KREDI KARTI',
    'BANKA KARTI',
    'PARA USTU',
    'INDIRIM',
    'PUAN',
    'PARA USTU',
    'FIS NO',
    'TARIH',
    'SAAT',
    'MERSIS',
    'VERGI',
    'EKU NO',
    'Z NO',
    'TESEKKUR',
  ];

  /// OCR'ın Latin harf yerine koyduğu görsel ikizleri düzeltir.
  ///
  /// Vision, fişteki çarpı işaretini Kiril "х" (U+0445) olarak okuyabiliyor —
  /// ekranda Latin "x" ile birebir aynı görünüyor ama farklı bir kod noktası,
  /// dolayısıyla "3 x 38,90" satırı tanınmıyordu. Aynı tuzak o/О, e/Е, a/А,
  /// c/С gibi harflerde de var; hepsi burada tek yerde çözülüyor.
  static String fixHomoglyphs(String s) {
    const map = {
      'а': 'a', 'А': 'A', 'в': 'b', 'В': 'B', 'с': 'c', 'С': 'C',
      'е': 'e', 'Е': 'E', 'н': 'h', 'Н': 'H', 'к': 'k', 'К': 'K',
      'м': 'm', 'М': 'M', 'о': 'o', 'О': 'O', 'р': 'p', 'Р': 'P',
      'т': 'T', 'Т': 'T', 'у': 'y', 'У': 'Y', 'х': 'x', 'Х': 'X',
      'і': 'i', 'І': 'I', 'ј': 'j', 'Ѕ': 'S', 'ѕ': 's',
      '×': 'x', 'Ｘ': 'X',
      // Romence virgüllü S/T, Türkçe çengelli karşılıklarıyla karışıyor.
      'Ș': 'Ş', 'ș': 'ş', 'Ț': 'T', 'ț': 't',
    };
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      buffer.write(map[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Türkçe karakterleri sadeleştirip büyük harfe çevirir — karşılaştırmalar
  /// OCR'ın harf hatalarına daha dayanıklı olsun diye.
  static String normalize(String s) {
    const from = 'ıİğĞüÜşŞöÖçÇâÂîÎûÛ';
    const to = 'IIGGUUSSOOCCAAIIUU';
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    // toUpperCase Türkçe'de i -> I yapıyor; harfler zaten yukarıda
    // sadeleştirildiği için sorun kalmıyor.
    return buffer.toString().toUpperCase();
  }

  /// "1.234,56" ve "123,45" -> double. Nokta binlik, virgül ondalık.
  static double? parseAmount(String s) {
    final m = RegExp(r'^-?\d{1,3}(?:\.\d{3})*,\d{2}$|^-?\d+,\d{2}$')
        .firstMatch(s);
    if (m == null) return null;
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  }

  /// "1,240" ya da "3" -> double. Miktar alanında ondalık virgülle geliyor.
  static double? parseQuantity(String s) {
    if (!RegExp(r'^\d+(?:[,.]\d{1,3})?$').hasMatch(s)) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  static final _amountAtEnd = RegExp(r'(-?[\d.]*\d,\d{2})\s*\*?$');
  static final _quantityLine = RegExp(
    r'^\s*(\d+(?:[,.]\d{1,3})?)\s*[xX*]\s*([\d.]*\d,\d{2})',
  );
  static final _dateRe = RegExp(r'(\d{2})[./-](\d{2})[./-](\d{4})');

  static ParsedReceipt parse(String rawText) {
    final text = fixHomoglyphs(rawText);
    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchantCode = _findMerchant(rawLines);
    final date = _findDate(rawLines);

    final lines = <ParsedLine>[];
    double? total;

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final upper = normalize(line);

      // Ayraç satırları.
      if (RegExp(r'^[-=*_.\s]+$').hasMatch(line)) continue;

      final amountMatch = _amountAtEnd.firstMatch(line);
      final isStop = _stopWords.any(upper.startsWith);

      if (isStop) {
        if (upper.startsWith('TOPLAM') && amountMatch != null) {
          total ??= parseAmount(amountMatch.group(1)!);
        }
        continue;
      }

      // "3 X 38,90    116,70" — bir önceki satırın miktar/birim fiyatı.
      final qtyMatch = _quantityLine.firstMatch(line);
      if (qtyMatch != null && lines.isNotEmpty) {
        final qty = parseQuantity(qtyMatch.group(1)!);
        final unit = parseAmount(qtyMatch.group(2)!);
        final amount = amountMatch == null
            ? null
            : parseAmount(amountMatch.group(1)!);
        final last = lines.removeLast();
        lines.add(
          ParsedLine(
            raw: last.raw,
            amount: amount ?? last.amount,
            quantity: qty ?? 1,
            unitPrice: unit,
          ),
        );
        continue;
      }

      if (amountMatch == null) {
        // Tutarsız satır bir sonraki satırda fiyatı olan ürün adı olabilir.
        final next = i + 1 < rawLines.length ? rawLines[i + 1] : null;
        if (next != null && _quantityLine.hasMatch(next)) {
          lines.add(ParsedLine(raw: _cleanName(line), amount: 0));
        }
        continue;
      }

      final amount = parseAmount(amountMatch.group(1)!);
      if (amount == null || amount <= 0) continue;

      final name = _cleanName(line.substring(0, amountMatch.start));
      if (name.isEmpty) continue;

      lines.add(ParsedLine(raw: name, amount: amount));
    }

    return ParsedReceipt(
      lines: lines.where((l) => l.amount > 0).toList(),
      merchantCode: merchantCode,
      date: date,
      total: total,
    );
  }

  /// Ürün adından KDV oranı, yıldız gibi kuyrukları atar.
  static String _cleanName(String s) => s
      .replaceAll(RegExp(r'\s*%\s*\d+\s*$'), '')
      .replaceAll(RegExp(r'[*#]+\s*$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  static String? _findMerchant(List<String> lines) {
    // Zincir adı fişin başında olur; ilk 8 satıra bakmak yeterli.
    final head = lines.take(8).map(normalize).join(' ');
    for (final entry in _chains.entries) {
      if (entry.value.any(head.contains)) return entry.key;
    }
    return null;
  }

  static DateTime? _findDate(List<String> lines) {
    for (final line in lines) {
      final m = _dateRe.firstMatch(line);
      if (m == null) continue;
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final year = int.parse(m.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      final parsed = DateTime(year, month, day);
      // Gelecekteki tarih OCR hatasıdır; fiş geçmişte kesilmiş olmalı.
      if (parsed.isAfter(DateTime.now().add(const Duration(days: 1)))) continue;
      return parsed;
    }
    return null;
  }
}
