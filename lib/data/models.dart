import 'product_name.dart';

/// Kanonik ürüne yapılan hafif atıf — eşleşme adayları ve zamlanan listesi
/// için ürünün tamamını çekmeye gerek yok.
class ProductRef {
  const ProductRef({
    required this.id,
    required this.name,
    required this.sizeLabel,
    this.brand,
    this.groupId,
    this.brandId,
    this.groupName,
    this.unit,
    this.sizeValue,
    this.score,
  });

  final String id;
  final String name;
  final String sizeLabel;

  /// Marka adı. Markasız kalemlerde (açık sebze, fırın ekmeği) null.
  final String? brand;

  /// Ürün grubu — "Yoğurt", "Bulgur, pilavlık".
  final String? groupName;

  /// Katalogda olmayan bir boy eklenirken gerekiyor.
  final String? groupId;
  final String? brandId;

  /// Grubun kanonik birimi: litre, kilogram ya da adet.
  final String? unit;

  /// Paket içeriği kanonik birim cinsinden: "400 g" -> 0,4 (kilogram).
  /// Birim fiyat bununla hesaplanıyor; etiketten sayı ayrıştırmak yanlış
  /// olurdu, çünkü etiketin birimi kanonik birim olmak zorunda değil.
  final double? sizeValue;

  /// Bulanık eşleştirmenin güven puanı, 0..1. Aramadan gelen adaylarda null.
  final double? score;

  String get title => '$name, $sizeLabel';

  /// Marka rozetindeki iki harf. Logo yok: fişin monospace'inde baş harfler.
  String get monogram {
    final source = brand ?? name;
    final flat = ProductName.expand(source)
        .replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü]'), '');
    if (flat.isEmpty) return '?';
    return flat.substring(0, flat.length >= 2 ? 2 : 1).toUpperCase();
  }

  static ProductRef fromJson(Map<String, dynamic> j) => ProductRef(
    id: j['id'] as String,
    name: j['name'] as String,
    sizeLabel: (j['sizeLabel'] ?? '') as String,
    brand: j['brand'] as String?,
    groupId: j['groupId'] as String?,
    brandId: j['brandId'] as String?,
    groupName: j['groupName'] as String?,
    unit: j['unit'] as String?,
    sizeValue: (j['sizeValue'] as num?)?.toDouble(),
    score: (j['score'] as num?)?.toDouble(),
  );
}

/// Bir fiş satırı için sunucunun önerdiği adaylar.
class MatchSuggestion {
  const MatchSuggestion({
    required this.candidates,
    required this.sizeAmbiguous,
  });

  final List<ProductRef> candidates;

  /// Marka ve grup çözüldü, geriye yalnızca gramaj kaldı. Fişte yazmadığı
  /// için sorulmak zorunda — ve endeks birim fiyat üzerinden hesaplandığı
  /// için doğru olmak zorunda.
  final bool sizeAmbiguous;

  static const empty = MatchSuggestion(candidates: [], sizeAmbiguous: false);

  static MatchSuggestion fromJson(Map<String, dynamic> j) => MatchSuggestion(
    sizeAmbiguous: j['sizeAmbiguous'] == true,
    candidates: ((j['candidates'] as List?) ?? const [])
        .map((e) => ProductRef.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Sepetteki kanonik ürün ve gözlem geçmişi.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sizeLabel,
    required this.observations,
    required this.merchantCount,
    required this.monthSpan,
    required this.changePct,
    this.firstPackPrice,
    this.lastPackPrice,
    this.history = const [],
    this.byMerchant = const [],
  });

  final String id;
  final String name;
  final String sizeLabel;
  final int observations;
  final int merchantCount;
  final int monthSpan;

  /// İlk gözlemden bugüne birim fiyat değişimi, yüzde. Tek gözlem varsa null.
  final double? changePct;

  /// Ekranda gösterilen paket fiyatı — endeks birim fiyat kullanıyor, bu ayrı.
  final double? firstPackPrice;
  final double? lastPackPrice;

  final List<PricePoint> history;
  final List<MarketPrice> byMerchant;

  String get title => '$name\n$sizeLabel';
  String get listTitle => '$name, $sizeLabel';

  static Product fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    sizeLabel: (j['sizeLabel'] ?? '') as String,
    observations: (j['observations'] as num?)?.toInt() ?? 0,
    merchantCount: (j['merchantCount'] as num?)?.toInt() ?? 0,
    monthSpan: (j['monthSpan'] as num?)?.toInt() ?? 0,
    changePct: (j['changePct'] as num?)?.toDouble(),
    firstPackPrice: (j['firstPackPrice'] as num?)?.toDouble(),
    lastPackPrice: (j['lastPackPrice'] as num?)?.toDouble(),
    history: (j['history'] as List? ?? const [])
        .map((e) => PricePoint.fromJson(e as Map<String, dynamic>))
        .toList(),
    byMerchant: (j['byMerchant'] as List? ?? const [])
        .map((e) => MarketPrice.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PricePoint {
  const PricePoint(this.date, this.packPrice, this.unitPrice);

  final DateTime date;
  final double packPrice;
  final double unitPrice;

  static PricePoint fromJson(Map<String, dynamic> j) => PricePoint(
    DateTime.parse(j['date'] as String),
    (j['packPrice'] as num).toDouble(),
    (j['unitPrice'] as num).toDouble(),
  );
}

class MarketPrice {
  const MarketPrice(this.market, this.packPrice);

  final String market;
  final double packPrice;

  static MarketPrice fromJson(Map<String, dynamic> j) =>
      MarketPrice(j['merchant'] as String, (j['packPrice'] as num).toDouble());
}

/// Taranmış fiş.
class Receipt {
  const Receipt({
    required this.id,
    required this.merchant,
    required this.date,
    required this.itemCount,
    required this.total,
    this.pendingCount = 0,
    this.lines = const [],
  });

  final String id;
  final String merchant;
  final DateTime date;
  final int itemCount;
  final double total;

  /// Eşleşme onayı bekleyen satır sayısı.
  final int pendingCount;

  /// Satır kırılımı — listede boş, detayda dolu.
  final List<ReceiptLine> lines;

  static Receipt fromJson(Map<String, dynamic> j) {
    final lines = (j['lines'] as List? ?? const [])
        .map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
        .toList();
    return Receipt(
      id: j['id'] as String,
      merchant: j['merchant'] as String,
      date: DateTime.parse(j['purchasedAt'] as String),
      itemCount: (j['itemCount'] as num?)?.toInt() ?? lines.length,
      total: (j['total'] as num).toDouble(),
      pendingCount:
          (j['pendingCount'] as num?)?.toInt() ??
          lines.where((l) => l.needsMatch).length,
      lines: lines,
    );
  }
}

/// Fişteki tek satır. [raw] OCR'dan geldiği gibi, [canonical] eşleştiği ürün.
class ReceiptLine {
  const ReceiptLine({
    required this.id,
    required this.raw,
    required this.canonical,
    required this.amount,
    required this.quantity,
    this.needsMatch = false,
    this.status = 'auto',
  });

  final String id;
  final String raw;

  /// Henüz eşleşmediyse null.
  final String? canonical;
  final double amount;
  final double quantity;

  /// Normalizasyon emin olamadı — kullanıcıya soruluyor. Bu bayrak hem
  /// doğruluğu artırıyor hem her satır için model çağırmayı engelliyor.
  final bool needsMatch;

  /// Sunucudaki durum: auto, confirmed, pending, excluded.
  final String status;

  /// Kasa poşeti gibi ürün olmayan kalem. Endekse girmiyor ve sorulmuyor.
  bool get isExcluded => status == 'excluded';

  /// "SUT TAM YAGLI 1L · x3"
  /// Kısaltmaları açılmış hâli — bkz. [ProductName].
  String get displayName => ProductName.expand(raw);

  String get rawLine => quantity == 1 ? raw : '$raw · x${qtyLabel(quantity)}';

  static String qtyLabel(double q) => q == q.roundToDouble()
      ? q.toInt().toString()
      : q.toString().replaceAll('.', ',');

  static ReceiptLine fromJson(Map<String, dynamic> j) => ReceiptLine(
    id: j['id'] as String,
    raw: j['raw'] as String,
    canonical: j['canonical'] as String?,
    amount: (j['amount'] as num).toDouble(),
    quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
    needsMatch: j['status'] == 'pending',
    status: (j['status'] ?? 'auto') as String,
  );
}

/// Karşılaştırma için çekilen resmî / bağımsız enflasyon kaynağı.
class DataSource {
  const DataSource({
    required this.code,
    required this.publisher,
    required this.name,
    required this.official,
    required this.value,
  });

  final String code;
  final String publisher;
  final String name;

  /// Resmî kurum mu, bağımsız ölçüm mü.
  final bool official;

  /// Son 12 aylık değişim. Veri henüz çekilmediyse null — uydurmuyoruz.
  final double? value;

  String get title => '$publisher $name';

  static DataSource fromJson(Map<String, dynamic> j) => DataSource(
    code: j['code'] as String,
    publisher: j['publisher'] as String,
    name: j['name'] as String,
    official: j['isOfficial'] as bool? ?? false,
    value: (j['yoyPct'] as num?)?.toDouble(),
  );
}

/// Aylık kartta gösterilen "en çok zamlanan" satırı.
class Mover {
  const Mover({
    required this.productId,
    required this.name,
    required this.sizeLabel,
    required this.pct,
  });

  final String productId;
  final String name;
  final String sizeLabel;
  final double pct;

  String get title => '$name, $sizeLabel';

  static Mover fromJson(Map<String, dynamic> j) => Mover(
    productId: j['productId'] as String,
    name: j['name'] as String,
    sizeLabel: (j['sizeLabel'] ?? '') as String,
    pct: (j['changePct'] as num).toDouble(),
  );
}

/// Market. Fiş kaydederken seçiliyor.
class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.chainCode,
  });

  final String id;
  final String name;
  final String chainCode;

  static Merchant fromJson(Map<String, dynamic> j) => Merchant(
    id: j['id'] as String,
    name: j['name'] as String,
    chainCode: j['chainCode'] as String,
  );
}

/// Kırılım serisindeki tek ay.
class BreakdownPoint {
  const BreakdownPoint({
    required this.month,
    required this.level,
    required this.coveredWeight,
  });

  final DateTime month;

  /// Zincirlenmiş endeks seviyesi; taban ayı 100.
  final double level;

  /// O ay hesaba giren ağırlık payı, 0..1. Düşükse seri ince buzda —
  /// ekranda uyarı olarak gösteriliyor.
  final double coveredWeight;

  static BreakdownPoint fromJson(Map<String, dynamic> j) => BreakdownPoint(
    month: DateTime.parse(j['month'] as String),
    level: (j['level'] as num).toDouble(),
    coveredWeight: (j['coveredWeight'] as num?)?.toDouble() ?? 0,
  );
}

/// Kategori ya da marka bazında endeks serisi.
///
/// Bunlar genel endeksin alt kalemleri DEĞİL, bağımsız serileri: her biri
/// kendi içinde yeniden ağırlıklandırılıyor, dolayısıyla toplandıklarında
/// genel endeksi vermezler. Ekrandaki metin bunu söylüyor.
class Breakdown {
  const Breakdown({
    required this.id,
    required this.name,
    required this.series,
    this.code,
  });

  final String id;
  final String name;

  /// Kategori kodu (TÜİK COICOP). Markada yok.
  final String? code;

  final List<BreakdownPoint> series;

  /// Taban aydan bugüne toplam değişim, yüzde. Taban 100 olduğu için
  /// son seviyeden doğrudan okunuyor.
  double get changePct => series.isEmpty ? 0 : series.last.level - 100;

  List<double> get levels => series.map((p) => p.level).toList();

  /// Serinin son ayındaki kapsama. Ekranda "ince buz" uyarısı için.
  double get lastCoverage => series.isEmpty ? 0 : series.last.coveredWeight;

  static Breakdown fromJson(Map<String, dynamic> j) => Breakdown(
    id: (j['categoryId'] ?? j['brandId']) as String,
    name: j['name'] as String,
    code: j['code'] as String?,
    series: (j['series'] as List? ?? const [])
        .map((e) => BreakdownPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Elle girilmiş tek bir ay: "2026 Temmuz, %33,5".
class OfficialEntry {
  const OfficialEntry({required this.month, required this.yoyPct});

  final DateTime month;

  /// Yıllık değişim. Seviye değil bu tutuluyor: kaynaklar zaten yıllık
  /// yüzdeyi açıklıyor, seviyeden yeniden hesaplamak yuvarlama farkı üretir.
  final double yoyPct;

  static OfficialEntry fromJson(Map<String, dynamic> j) => OfficialEntry(
    month: DateTime.parse(j['month'] as String),
    yoyPct: (j['yoyPct'] as num).toDouble(),
  );
}

/// Resmî ya da bağımsız bir seri ve girilmiş bütün ayları.
class OfficialSeries {
  const OfficialSeries({
    required this.code,
    required this.publisher,
    required this.name,
    required this.official,
    required this.entries,
  });

  final String code;
  final String publisher;
  final String name;

  /// Resmî kurum mu, bağımsız ölçüm mü. Şimdilik yalnızca TÜİK var; alan
  /// duruyor çünkü bağımsız bir kaynak eklendiğinde ayrım gerekecek.
  final bool official;

  /// En yeniden eskiye.
  final List<OfficialEntry> entries;

  String get title => '$publisher $name';

  static OfficialSeries fromJson(Map<String, dynamic> j) => OfficialSeries(
    code: j['code'] as String,
    publisher: j['publisher'] as String,
    name: j['name'] as String,
    official: j['isOfficial'] as bool? ?? false,
    entries: (j['entries'] as List? ?? const [])
        .map((e) => OfficialEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
