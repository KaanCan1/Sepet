import 'package:flutter/widgets.dart';

/// Kanonik ürün — fişteki ham satırların eşleştiği referans kayıt.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.size,
    required this.observations,
    required this.marketCount,
    required this.monthSpan,
    required this.history,
    required this.byMarket,
  });

  final String id;

  /// "Ayçiçek yağı"
  final String name;

  /// "5 litre"
  final String size;

  final int observations;
  final int marketCount;
  final int monthSpan;

  /// Kronolojik fiyat gözlemleri.
  final List<PricePoint> history;

  /// Marketlerde en son görülen fiyatlar.
  final List<MarketPrice> byMarket;

  double get first => history.first.price;
  double get last => history.last.price;
  double get changePct => (last - first) / first * 100;

  String get title => '$name\n$size';
}

class PricePoint {
  const PricePoint(this.date, this.price);
  final DateTime date;
  final double price;
}

class MarketPrice {
  const MarketPrice(this.market, this.price);
  final String market;
  final double price;
}

/// Taranmış fiş.
class Receipt {
  const Receipt({
    required this.id,
    required this.market,
    required this.city,
    required this.date,
    required this.itemCount,
    required this.total,
    this.lines = const [],
  });

  final String id;
  final String market;
  final String? city;
  final DateTime date;

  final int itemCount;
  final double total;

  /// Satır kırılımı — tarama akışında dolu, listede boş bırakılabilir.
  final List<ReceiptLine> lines;

  /// "A101 · Kırklareli"
  String get heading => city == null ? market : '$market · $city';
}

/// Fişteki tek satır. [raw] OCR'dan geldiği gibi, [canonical] normalizasyon
/// katmanının önerdiği kanonik ad.
class ReceiptLine {
  const ReceiptLine({
    required this.raw,
    required this.canonical,
    required this.amount,
    this.qtyLabel,
    this.needsMatch = false,
    this.candidates = const [],
  });

  final String raw;
  final String canonical;
  final double amount;

  /// "x3" veya "1,240 kg"
  final String? qtyLabel;

  /// Normalizasyon emin değilse kullanıcıya sorulur — LLM çağrısını da,
  /// yanlış endeksi de bu bayrak engelliyor.
  final bool needsMatch;
  final List<String> candidates;

  String get rawLine => qtyLabel == null ? raw : '$raw · $qtyLabel';

  ReceiptLine confirmedAs(String name) => ReceiptLine(
        raw: raw,
        canonical: name,
        amount: amount,
        qtyLabel: qtyLabel,
        needsMatch: false,
        candidates: candidates,
      );
}

/// Endeks serisi — senin sepetin, TÜİK, ENAG.
class Series {
  const Series({
    required this.name,
    required this.color,
    required this.value,
    required this.points,
    this.dashed = false,
  });

  final String name;
  final Color color;

  /// 12 aylık değişim, yüzde.
  final double value;

  /// 0..1 aralığına ölçeklenmemiş ham seri.
  final List<double> points;
  final bool dashed;
}

/// Aylık kartta gösterilen "en çok zamlanan" satırı.
class Mover {
  const Mover(this.name, this.pct);
  final String name;
  final double pct;
}

/// Karşılaştırma için çekilen resmî / bağımsız enflasyon kaynağı.
class DataSource {
  const DataSource({
    required this.name,
    required this.publisher,
    required this.official,
    required this.value,
    required this.lastRelease,
    required this.nextRelease,
  });

  final String name;
  final String publisher;

  /// Resmî kurum mu, bağımsız ölçüm mü.
  final bool official;

  /// Son 12 aylık değişim, yüzde.
  final double value;

  final DateTime lastRelease;
  final DateTime nextRelease;
}
