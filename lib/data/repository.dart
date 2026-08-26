import 'api.dart';
import 'models.dart';
import 'session.dart';

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

  /// Açık oturumun sahibi. Jeton geçersizse 401 dönüyor — açılıştaki
  /// doğrulama bu ucu kullanıyor, çünkü endeksin hesaplanması gerekmiyor.
  Future<Session> me() async {
    final json = await _api.get('/account/me') as Map<String, dynamic>;
    return Session(
      provider: AuthProvider.email,
      email: json['email'] as String?,
    );
  }

  Future<IndexSnapshot> index() async =>
      IndexSnapshot.fromJson(await _api.get('/index') as Map<String, dynamic>);

  Future<List<Mover>> movers() async {
    final rows = await _api.get('/index/movers') as List;
    return rows.map((e) => Mover.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Kategori kırılımı — en çok artandan başlayarak.
  Future<List<Breakdown>> indexByCategory() async {
    final rows = await _api.get('/index/by-category') as List;
    return rows
        .map((e) => Breakdown.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marka kırılımı. Markasız kalemler (kasada tartılan sebze) bu seride
  /// hiç yok — sunucu onları dışarıda bırakıyor, marka uydurulmuyor.
  Future<List<Breakdown>> indexByBrand() async {
    final rows = await _api.get('/index/by-brand') as List;
    return rows
        .map((e) => Breakdown.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bütün fişleri ve türetilmiş endeksi siler; hesabı bırakır.
  ///
  /// Demo veriden gerçek fişlere geçerken gereken şey bu: hesap, izinler ve
  /// öğrenilmiş eşleşmeler kalıyor, endeks sıfırdan kuruluyor.
  Future<int> clearReceipts() async {
    final res = await _api.delete('/receipts') as Map<String, dynamic>;
    return (res['deletedReceipts'] as num?)?.toInt() ?? 0;
  }

  /// Hesabı ve ona bağlı her şeyi siler.
  /// Tek fişi siler ve endeksi yeniden hesaplatır.
  Future<void> deleteReceipt(String id) => _api.delete('/receipts/$id');

  Future<void> deleteAccount() => _api.delete('/account');

  /// Resmî ve bağımsız seriler, girilmiş aylarıyla.
  ///
  /// Şimdilik elle giriliyor: TÜİK'in kendi portalı otomatik erişime kapalı,
  /// resmî kanal olan TCMB EVDS ise API anahtarı istiyor. Sayı uydurmak
  /// seçenek değil — uygulamanın bütün iddiası ölçülen sayıların gerçek
  /// olması.
  Future<List<OfficialSeries>> officialSeries() async {
    final rows = await _api.get('/official') as List;
    return rows
        .map((e) => OfficialSeries.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bir ayı yazar ya da düzeltir. [month] ayın ilk günü olmalı.
  Future<void> saveOfficial({
    required String code,
    required DateTime month,
    required double yoyPct,
  }) => _api.put('/official/$code/${_monthKey(month)}', {'yoyPct': yoyPct});

  /// TÜİK TÜFE'yi TCMB EVDS'ten çeker. Yazılan ay sayısını döndürür.
  Future<int> refreshOfficial() async {
    final res = await _api.post('/official/refresh') as Map<String, dynamic>;
    return (res['written'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteOfficial({
    required String code,
    required DateTime month,
  }) => _api.delete('/official/$code/${_monthKey(month)}');

  static String _monthKey(DateTime m) =>
      '${m.year.toString().padLeft(4, '0')}-'
      '${m.month.toString().padLeft(2, '0')}-01';

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

  /// Son sepetin karşılaştırması. Kıyaslanacak veri yoksa
  /// [BasketCompare.none] — hata değil, ekranın sessiz kalacağı durum.
  Future<BasketCompare> basketCompare() async => BasketCompare.fromJson(
    await _api.get('/index/basket') as Map<String, dynamic>,
  );

  Future<Product> product(String id) async =>
      Product.fromJson(await _api.get('/products/$id') as Map<String, dynamic>);

  /// Ham fiş metni için sıralı aday listesi. Kullanıcı hiçbir şey yazmadan
  /// önce doğru ürün genelde ilk sırada oluyor.
  Future<MatchSuggestion> suggestMatches(String raw) async {
    final json = await _api.get(
      '/products/catalog/suggest?raw=${Uri.encodeQueryComponent(raw)}',
    );
    return MatchSuggestion.fromJson(json as Map<String, dynamic>);
  }

  /// Katalogda olmayan bir boyu ekler ve kanonik ürünü döndürür.
  ///
  /// Aynı marka + grup + boy ikinci kez istendiğinde mevcut olan dönüyor;
  /// katalog kullanıcı eliyle büyürken ikizlenmiyor.
  Future<ProductRef> addCatalogSize({
    required String groupId,
    String? brandId,
    required String sizeLabel,
    required double sizeValue,
  }) async {
    final json = await _api.post('/products/catalog', {
      'groupId': groupId,
      'brandId': brandId,
      'sizeLabel': sizeLabel,
      'sizeValue': sizeValue,
    });
    return ProductRef.fromJson(json as Map<String, dynamic>);
  }

  /// Ürün grupları, istenirse ölçü birimine göre süzülmüş.
  ///
  /// Gramaj ekranı bunu yalnızca kullanıcı grubun boyutunu değiştiren bir
  /// birim seçtiğinde çağırıyor — gram giriliyorsa doğru grup litre
  /// cinsinden olamaz.
  Future<List<ProductGroupRef>> catalogGroups({
    required String unit,
    String query = '',
  }) async {
    final rows = await _api.get(
      '/products/catalog/groups?unit=${Uri.encodeQueryComponent(unit)}'
      '&q=${Uri.encodeQueryComponent(query)}',
    ) as List;
    return rows
        .map((e) => ProductGroupRef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Kategoriler — yeni grup tanımlanırken seçiliyor.
  Future<List<Category>> catalogCategories() async {
    final rows = await _api.get('/products/catalog/categories') as List;
    return rows
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Katalogda hiç olmayan bir ürünü tanımlar.
  ///
  /// Kullanıcının çıkmazı buydu: fişteki kalem katalogda yoksa yapabileceği
  /// tek şey yanlış bir ürün seçmek ya da satırı sonsuza kadar bekletmekti.
  /// İlki endeksi bozuyor, ikincisi kapsamı daraltıyor.
  ///
  /// Aynı ürün ikinci kez tanımlanırsa katalog ikizlenmiyor; sunucu mevcut
  /// olanı döndürüyor.
  Future<ProductRef> defineProduct({
    required String categoryCode,
    required String groupName,
    required String unit,
    String? brandName,
    required String sizeLabel,
    required double sizeValue,
  }) async {
    final json = await _api.post('/products/catalog/define', {
      'categoryCode': categoryCode,
      'groupName': groupName,
      'unit': unit,
      'brandName': brandName,
      'sizeLabel': sizeLabel,
      'sizeValue': sizeValue,
    });
    return ProductRef.fromJson(json as Map<String, dynamic>);
  }

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
