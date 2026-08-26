/// Cihaz üstünde OCR'dan çıkan ham metni fiş satırlarına çevirir.
///
/// Tamamen saf Dart: kamera, ağ ya da eklenti yok. Türk market fişlerinin
/// biçimi burada tek yerde toplanıyor ve testlerle tutuluyor — OCR'ın kendisi
/// değişse de bu katman aynı kalır.
library;

import 'product_name.dart';

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

  /// Kısaltmaları açılmış, okunur ad. Ekranda ve düzeltme alanında bu
  /// gösteriliyor; [raw] sunucudaki alias anahtarı olduğu için değişmiyor.
  String get displayName => ProductName.expand(raw);

  ParsedLine _with({double? amount, double? quantity, double? unitPrice}) =>
      ParsedLine(
        raw: raw,
        amount: amount ?? this.amount,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

/// Fişin tamamı.
class ParsedReceipt {
  const ParsedReceipt({
    required this.lines,
    this.merchantCode,
    this.merchantName,
    this.date,
    this.total,
  });

  final List<ParsedLine> lines;

  /// Tanınan zincir kodu (BIM, A101 …). Tanınmadıysa kullanıcı seçecek.
  final String? merchantCode;

  /// Zincir tanınmadıysa fişin başlığından okunan ad — "ONUR LULEBURGAZ
  /// TASKIN" gibi. Market ekleme alanına ön dolgu olarak giriyor; doğru
  /// olduğu iddiasında değil, kullanıcı düzeltiyor.
  final String? merchantName;

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

  /// Fişin özet bölümünü açan satırlar. Bunlardan sonrası ürün değil.
  ///
  /// Kart, onay ve referans satırları da tutar taşıyor; ürün taramasını
  /// burada kesmek onları tek tek elemekten çok daha sağlam.
  static const _summaryOpeners = [
    'ARA TOPLAM',
    'ARATOPLAM',
    'TOPKDV',
    'TOPLAM KDV',
    'TOPLAM',
    'ODENECEK',
    'GENEL TOPLAM',
  ];

  /// KDV satırları. "TOPLAM KDV" fişin toplamı değil, verginin toplamı —
  /// ikisi karışırsa fiş 431,62 yerine 4,27 TL sanılıyor.
  static const _vatWords = [
    'TOPLAM KDV',
    'TOPKDV',
    'KDV TUTAR',
    'KDV MATRAH',
    'KDV DAHIL',
  ];

  /// Ürün olmayan, tutar taşıyabilen satırlar.
  static const _skipWords = [
    'NAKIT',
    'KREDI KARTI',
    'BANKA KARTI',
    'BANKA KREDI',
    'ORTAK POS',
    'PARA USTU',
    'INDIRIM',
    'PUAN',
    'FIS NO',
    'TARIH',
    'SAAT',
    'MERSIS',
    'VERGI',
    'EKU NO',
    'Z NO',
    'TESEKKUR',
    'FATURA',
    'ETTN',
    'TCKN',
    'VKN',
    'ONAY NO',
    'REF NO',
    'REF.NO',
    'KASIYER',
    'POS:',
    'SATIS',
    'IMZA',
    'TERMINAL',
    'ISYERI',
    'MUSTERI',
    'BILGI FISI',
    'TUR:',
    'MONEY ILE',
    'IRSALIYE',
    'HTTP',
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

  /// Fiş tutarı -> double.
  ///
  /// İki ayraç düzeni de dolaşımda: yazarkasa fişleri "1.234,56" basıyor,
  /// e-arşiv faturaları (BİM) "195.62". Kuruş her ikisinde de iki hane,
  /// ayırt etmek için kullanılan da bu — "1.234" tutar değil.
  static double? parseAmount(String s) {
    final t = s.trim();
    if (RegExp(r'^-?\d{1,3}(?:\.\d{3})*,\d{2}$|^-?\d+,\d{2}$').hasMatch(t)) {
      return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
    }
    if (RegExp(r'^-?\d{1,3}(?:,\d{3})*\.\d{2}$|^-?\d+\.\d{2}$').hasMatch(t)) {
      return double.tryParse(t.replaceAll(',', ''));
    }
    return null;
  }

  /// "1,240" ya da "3" -> double. Miktar alanında ondalık virgülle geliyor.
  static double? parseQuantity(String s) {
    if (!RegExp(r'^\d+(?:[,.]\d{1,3})?$').hasMatch(s)) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  // ── Satır biçimleri ───────────────────────────────────────────────
  //
  // Tutar kolonu üç ayrı biçimde geliyor ve üçü de aynı fişte olabiliyor:
  //
  //   113,12        klasik yazarkasa
  //   *195.62       e-arşiv; yıldız kolon işareti, ondalık nokta
  //   *289  00      Vision kuruşu ayrı gözlem olarak döndürdü, araya
  //                 birleştiricinin koyduğu boşluk girdi
  //
  // Üçüncüsü tehlikeli: ayraçsız "289 00" barkodda da geçer. Bu yüzden
  // yalnızca başında kolon işareti varken kabul ediliyor.
  static final _amountSep = RegExp(
    r'(?:[*#]\s*)?(\d{1,3}(?:[.,]\d{3})*|\d+)\s*([.,])\s*(\d{2})\s*\*?$',
  );
  static final _amountSpaced = RegExp(
    r'[*#xX]\s*(\d{1,3}(?:[.,]\d{3})*|\d+)\s+(\d{2})\s*$',
  );

  /// "0,983 kg X 199.00" / "4 ad X 59.00" / "3 X 37,71".
  ///
  /// Birim adı (kg, ad, lt …) sayı ile çarpı arasına giriyor; e-arşiv
  /// faturalarında hep var, yazarkasa fişlerinde hiç yok.
  static final _quantityLine = RegExp(
    r'^\s*(\d+(?:[,.]\d{1,3})?)\s*'
    r'(?:kg|kilogram|gr?|ad|adet|lt|litre|l|ml|cl|pk|paket)?\s*'
    r'[xX*]\s*'
    r'(\d{1,3}(?:[.,]\d{3})*[.,]\d{2}|\d+[.,]\d{2})',
    caseSensitive: false,
  );

  static final _dateRe = RegExp(r'(\d{2})[./-](\d{2})[./-](\d{4})');

  /// Satır sonundaki tutarı bulur. Bulursa (başlangıç, değer) döner.
  static ({int start, double value})? _amountAtEnd(String line) {
    final sep = _amountSep.firstMatch(line);
    if (sep != null) {
      final v = parseAmount('${sep.group(1)}${sep.group(2)}${sep.group(3)}');
      if (v != null) return (start: sep.start, value: v);
    }
    final spaced = _amountSpaced.firstMatch(line);
    if (spaced != null) {
      final v = parseAmount('${spaced.group(1)},${spaced.group(2)}');
      if (v != null) return (start: spaced.start, value: v);
    }
    return null;
  }

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
    double? odenecek;
    var inSummary = false;

    // e-arşiv düzeninde miktar satırı ürün adından ÖNCE geliyor:
    //   0,983 kg X 199.00
    //   PILIÇ BONFİLE  %1
    //   *195.62
    // Yazarkasa fişinde ise sonra. İkisini de karşılamak için miktar
    // beklemede tutuluyor.
    ({double qty, double? unit})? pendingQty;

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final upper = normalize(line);

      if (RegExp(r'^[-=*_.\s]+$').hasMatch(line)) continue;

      final isVat = _vatWords.any(upper.startsWith);
      final opensSummary = _summaryOpeners.any(upper.startsWith);

      if (opensSummary) {
        inSummary = true;
        final amount =
            _amountAtEnd(line)?.value ??
            (i + 1 < rawLines.length ? _amountOnly(rawLines[i + 1]) : null);
        if (amount != null && !isVat) {
          if (upper.startsWith('ODENECEK')) {
            odenecek ??= amount;
          } else if (upper.startsWith('TOPLAM') &&
              !upper.startsWith('TOPKDV')) {
            total ??= amount;
          }
        }
        continue;
      }

      if (inSummary) continue;
      if (_skipWords.any(upper.contains)) continue;

      final qtyMatch = _quantityLine.firstMatch(line);
      if (qtyMatch != null) {
        final qty =
            parseQuantity(qtyMatch.group(1)!.replaceAll('.', ',')) ??
            parseQuantity(qtyMatch.group(1)!) ??
            1;
        final unit = parseAmount(qtyMatch.group(2)!);
        final tail = _amountAtEnd(line);

        // Çarpımdan sonra ayrıca tutar yazılmışsa satır tamamlanmış
        // demektir; bir önceki ürün adına iliştiriliyor.
        final hasOwnAmount = tail != null && tail.start > qtyMatch.end - 1;
        if (hasOwnAmount && lines.isNotEmpty) {
          final last = lines.removeLast();
          lines.add(
            last._with(amount: tail.value, quantity: qty, unitPrice: unit),
          );
        } else {
          pendingQty = (qty: qty, unit: unit);
        }
        continue;
      }

      final tail = _amountAtEnd(line);
      final name = _cleanName(
        tail == null ? line : line.substring(0, tail.start),
      );

      // Yalnızca tutar taşıyan satır: bir önceki ürün adının bedeli.
      if (tail != null && !_looksLikeName(name)) {
        if (lines.isNotEmpty && lines.last.amount == 0) {
          final last = lines.removeLast();
          lines.add(last._with(amount: tail.value));
        }
        continue;
      }

      if (!_looksLikeName(name)) continue;

      if (tail != null) {
        lines.add(
          ParsedLine(
            raw: name,
            amount: tail.value,
            quantity: pendingQty?.qty ?? 1,
            unitPrice: pendingQty?.unit,
          ),
        );
        pendingQty = null;
        continue;
      }

      // Tutarı olmayan ürün adı: bedeli izleyen satırlarda.
      final next = i + 1 < rawLines.length ? rawLines[i + 1] : null;
      final nextIsAmount = next != null && _amountOnly(next) != null;
      final nextIsQty = next != null && _quantityLine.hasMatch(next);
      if (nextIsAmount || nextIsQty || pendingQty != null) {
        lines.add(
          ParsedLine(
            raw: name,
            amount: 0,
            quantity: pendingQty?.qty ?? 1,
            unitPrice: pendingQty?.unit,
          ),
        );
        pendingQty = null;
      }
    }

    return ParsedReceipt(
      lines: lines.where((l) => l.amount > 0).toList(),
      merchantCode: merchantCode,
      merchantName: merchantCode == null ? _findMerchantName(rawLines) : null,
      date: date,
      total: odenecek ?? total,
    );
  }

  /// Satır baştan sona yalnızca bir tutar mı? ("*195.62")
  static double? _amountOnly(String line) {
    final t = line.trim();
    if (!RegExp(r'^[*#]?\s*[\d.,\s]+$').hasMatch(t)) return null;
    return _amountAtEnd(t)?.value;
  }

  /// Ürün adı olabilir mi? En az iki harf taşımayan şey ad değildir —
  /// "*****1154" ya da "180342" ürün olamaz.
  static bool _looksLikeName(String s) =>
      RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü].*[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(s);

  /// Ürün adından KDV oranı kolonunu, kampanya yıldızlarını ve kolon
  /// işaretlerini atar.
  static String _cleanName(String s) => s
      .replaceAll(RegExp(r'%\s*\d+\s*[.,]?'), ' ')
      .replaceAll(RegExp(r'^[\s*#+\-]+'), '')
      .replaceAll(RegExp(r'[\s*#]+$'), '')
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

  /// Zincir tanınmadığında fişin başlığındaki ad.
  ///
  /// Yerel marketlerin listede olmaması fişi kaydetmenin önünde duruyordu.
  /// Ad tahmini basit ve bilerek öyle: rakam içermeyen, yeterince uzun ilk
  /// başlık satırı. Yanlış tahmin pahalı değil — kullanıcı alanı düzenleyip
  /// kaydediyor; boş bırakmak ise ona baştan yazdırıyor.
  static String? _findMerchantName(List<String> lines) {
    for (final line in lines.take(4)) {
      final t = line.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (t.length < 3 || t.length > 40) continue;
      if (RegExp(r'[0-9]').hasMatch(t)) continue;
      if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]{3}').hasMatch(t)) continue;
      return t;
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
