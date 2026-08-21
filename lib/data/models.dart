/// Kanonik ürüne yapılan hafif atıf — eşleşme adayları ve zamlanan listesi
/// için ürünün tamamını çekmeye gerek yok.
class ProductRef {
  const ProductRef({
    required this.id,
    required this.name,
    required this.sizeLabel,
  });

  final String id;
  final String name;
  final String sizeLabel;

  String get title => '$name, $sizeLabel';

  static ProductRef fromJson(Map<String, dynamic> j) => ProductRef(
    id: j['id'] as String,
    name: j['name'] as String,
    sizeLabel: (j['sizeLabel'] ?? '') as String,
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

  /// "SUT TAM YAGLI 1L · x3"
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
