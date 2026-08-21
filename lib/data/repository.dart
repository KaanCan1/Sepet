import 'api.dart';
import 'models.dart';

/// Endeks ekranının tek seferde ihtiyaç duyduğu her şey.
class IndexSnapshot {
  const IndexSnapshot({
    required this.changePct,
    required this.windowMonths,
    required this.monthDeltaPoints,
    required this.levels,
    required this.official,
  });

  /// Pencere boyunca toplam değişim. Veri yoksa null.
  final double? changePct;

  /// Kaç aylık pencereye bakıldığı. 12 dolmadıysa daha küçük — ekrandaki
  /// etiket buna göre yazılıyor, yıllıklandırma yapılmıyor.
  final int windowMonths;

  final double? monthDeltaPoints;

  /// Zincirlenmiş endeks seviyeleri, kronolojik.
  final List<double> levels;

  final List<DataSource> official;

  bool get isEmpty => changePct == null || levels.length < 2;

  static IndexSnapshot fromJson(Map<String, dynamic> json) {
    final head = json['headline'] as Map<String, dynamic>?;
    final series = (json['series'] as List? ?? const [])
        .map((e) => ((e as Map)['level'] as num).toDouble())
        .toList();
    return IndexSnapshot(
      changePct: (head?['changePct'] as num?)?.toDouble(),
      windowMonths: (head?['windowMonths'] as num?)?.toInt() ?? 0,
      monthDeltaPoints: (head?['monthDeltaPoints'] as num?)?.toDouble(),
      levels: series,
      official: (json['official'] as List? ?? const [])
          .map((e) => DataSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Sunucuyla ekranlar arasındaki tek kapı.
class Repository {
  const Repository(this._api);

  final Api _api;

  Future<IndexSnapshot> index() async =>
      IndexSnapshot.fromJson(await _api.get('/index') as Map<String, dynamic>);

  Future<List<Mover>> movers() async {
    final rows = await _api.get('/index/movers') as List;
    return rows.map((e) => Mover.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Receipt>> receipts() async {
    final rows = await _api.get('/receipts') as List;
    return rows
        .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Receipt> receipt(String id) async =>
      Receipt.fromJson(await _api.get('/receipts/$id') as Map<String, dynamic>);

  Future<List<Product>> products() async {
    final rows = await _api.get('/products') as List;
    return rows
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> product(String id) async =>
      Product.fromJson(await _api.get('/products/$id') as Map<String, dynamic>);

  Future<List<ProductRef>> searchCatalog(String query) async {
    final rows = await _api.get(
      '/products/catalog/search?q=${Uri.encodeQueryComponent(query)}',
    ) as List;
    return rows
        .map((e) => ProductRef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Merchant>> merchants() async {
    final rows = await _api.get('/merchants') as List;
    return rows
        .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fişi kaydeder ve kimliğini döndürür. Sunucu satırları tek işlemde yazıp
  /// endeksi tazeliyor.
  Future<String> createReceipt({
    required String merchantId,
    required DateTime purchasedAt,
    required List<({String raw, double quantity, double amount})> lines,
  }) async {
    final res = await _api.post('/receipts', {
      'merchantId': merchantId,
      'purchasedAt': purchasedAt.toIso8601String().substring(0, 10),
      'lines': [
        for (final l in lines)
          {'raw': l.raw, 'quantity': l.quantity, 'amount': l.amount},
      ],
    }) as Map<String, dynamic>;
    return res['id'] as String;
  }

  Future<void> confirmMatch({
    required String receiptId,
    required String lineId,
    required String productId,
  }) => _api.post('/receipts/$receiptId/lines/$lineId/match', {
    'canonicalProductId': productId,
  });
}
