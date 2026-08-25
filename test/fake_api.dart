import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sepet/data/api.dart';

/// Sunucu yerine geçen sahte istemci. Testler ağ olmadan gerçek çözümleme
/// yolundan geçsin diye JSON döndürüyor — modelleri de birlikte doğruluyor.
class FakeApi extends Api {
  FakeApi({Map<String, Object?>? routes})
    : this._(_FakeClient(routes ?? defaultRoutes));

  // İstemci tek yerde kuruluyor: iki ayrı örnek yaratılırsa çağrıları
  // kaydeden nesne, isteklerin geçtiği nesne olmuyor ve calls hep boş
  // görünüyor.
  FakeApi._(_FakeClient client)
    : _client = client,
      super(baseUrl: 'http://fake', client: client);

  final _FakeClient _client;

  /// "GET /index" biçiminde, yapılan çağrılar. Testler bir düğmenin sunucuya
  /// gerçekten gidip gitmediğini buradan doğruluyor.
  List<String> get calls => _client.calls;

  /// İki ürün, üç ay: endeks 100 -> 116 -> 120,83 (%20,8).
  static Map<String, Object?> get defaultRoutes => {
    'POST /auth/dev-login': {'token': 'test-token', 'userId': 'u1'},
    'GET /index': {
      'headline': {
        'changePct': 20.8,
        'windowMonths': 2,
        'monthDeltaPoints': 4.2,
        'coveredWeight': 1,
      },
      'series': [
        {'month': '2026-06-01', 'level': 100, 'momPct': 0},
        {'month': '2026-07-01', 'level': 116, 'momPct': 16},
        {'month': '2026-08-01', 'level': 120.83, 'momPct': 4.16},
      ],
      'official': [
        {
          'code': 'TUIK_TUFE',
          'publisher': 'TÜİK',
          'name': 'TÜFE',
          'isOfficial': true,
          'yoyPct': null,
        },
      ],
    },
    'GET /index/movers': [
      {
        'productId': 'p1',
        'name': 'Yumurta',
        'sizeLabel': "30'lu",
        'changePct': 18.4,
      },
    ],
    // Kırılım: iki kategori, biri diğerinden daha çok artmış. Taban ay 100.
    'GET /index/by-category': [
      {
        'categoryId': 'c1',
        'code': '01.1.2',
        'name': 'Et',
        'latestLevel': 139.2,
        'series': [
          {'month': '2026-06-01', 'level': 100, 'coveredWeight': 0},
          {'month': '2026-07-01', 'level': 128.4, 'coveredWeight': 0.61},
          {'month': '2026-08-01', 'level': 139.2, 'coveredWeight': 0.58},
        ],
      },
      {
        'categoryId': 'c2',
        'code': '01.1.6',
        'name': 'Meyve',
        'latestLevel': 112.5,
        'series': [
          {'month': '2026-06-01', 'level': 100, 'coveredWeight': 0},
          {'month': '2026-07-01', 'level': 108.0, 'coveredWeight': 0.39},
          {'month': '2026-08-01', 'level': 112.5, 'coveredWeight': 0.42},
        ],
      },
    ],
    'GET /index/by-brand': [
      {
        'brandId': 'b1',
        'name': 'Sütaş',
        'latestLevel': 133.1,
        'series': [
          {'month': '2026-06-01', 'level': 100, 'coveredWeight': 0},
          {'month': '2026-07-01', 'level': 121.0, 'coveredWeight': 0.5},
          {'month': '2026-08-01', 'level': 133.1, 'coveredWeight': 0.5},
        ],
      },
    ],
    'DELETE /receipts': {'ok': true, 'deletedReceipts': 1},
    'DELETE /account': {'ok': true},
    'GET /official': [
      {
        'code': 'TUIK_TUFE',
        'publisher': 'TÜİK',
        'name': 'TÜFE',
        'isOfficial': true,
        'entries': [
          {'month': '2026-08-01', 'yoyPct': 33.5},
          {'month': '2026-07-01', 'yoyPct': 34.1},
        ],
      },
      {
        'code': 'TUIK_UFE',
        'publisher': 'TÜİK',
        'name': 'Yİ-ÜFE',
        'isOfficial': true,
        'entries': <Map<String, Object?>>[],
      },
    ],
    'POST /official/refresh': {'written': 14, 'newestMonth': '2026-07-01'},
    'PUT /official/TUIK_TUFE/2026-06-01': {
      'month': '2026-06-01',
      'yoyPct': 35.0,
    },
    'GET /receipts': [
      {
        'id': 'r1',
        'merchant': 'A101',
        'purchasedAt': '2026-08-18',
        'total': 842.6,
        'itemCount': 11,
        'pendingCount': 2,
      },
    ],
    'GET /receipts/r1': {
      'id': 'r1',
      'merchant': 'A101',
      'purchasedAt': '2026-08-18',
      'total': 842.6,
      'lines': [
        {
          'id': 'l1',
          'lineNo': 1,
          'raw': 'SUT TAM YAGLI 1L',
          'quantity': 3,
          'amount': 116.7,
          'status': 'auto',
          'canonical': 'Süt, tam yağlı 1 litre',
        },
        {
          'id': 'l2',
          'lineNo': 2,
          'raw': 'YUMURTA 30LU',
          'quantity': 1,
          'amount': 184.5,
          'status': 'pending',
          'canonical': null,
        },
        // Kasa poşeti: ürün değil, endekse girmiyor ve sorulmuyor.
        {
          'id': 'l3',
          'lineNo': 3,
          'raw': 'POSET',
          'quantity': 1,
          'amount': 1.0,
          'status': 'excluded',
          'canonical': null,
        },
      ],
    },
    // Gramaj belirsiz: marka ve ürün çözülmüş, geriye yalnızca boy kalmış.
    // Ölçü boyutu değiştiğinde açılan grup seçimi. Sunucu birime göre
    // süzüyor; sahte istemci sorgu dizesini yok saydığı için liste sabit.
    'GET /products/catalog/groups': [
      {'id': 'g-beyaz', 'name': 'Beyaz peynir', 'unit': 'kilogram'},
      {'id': 'g-kasar', 'name': 'Kaşar peyniri', 'unit': 'kilogram'},
    ],
    'POST /products/catalog': {
      'id': 'yeni-1',
      'name': 'Beyaz peynir',
      'groupName': 'Beyaz peynir',
      'brand': null,
      'sizeLabel': '400 g',
    },
    'GET /products/catalog/suggest': {
      'sizeAmbiguous': true,
      'autoId': null,
      'candidates': [
        {
          'id': 'y1',
          'name': 'Yumurta',
          'groupId': 'g-yumurta',
          'groupName': 'Yumurta',
          'brandId': null,
          'brand': null,
          'sizeLabel': "15'li",
          'sizeValue': 15,
          'unit': 'adet',
          'score': 0.91,
        },
        {
          'id': 'y2',
          'name': 'Yumurta',
          'groupId': 'g-yumurta',
          'groupName': 'Yumurta',
          'brandId': null,
          'brand': null,
          'sizeLabel': "30'lu",
          'sizeValue': 30,
          'unit': 'adet',
          'score': 0.91,
        },
      ],
    },
    'GET /products': [
      {
        'id': 'p1',
        'name': 'Ayçiçek yağı',
        'sizeLabel': '5 litre',
        'observations': 14,
        'merchantCount': 4,
        'monthSpan': 11,
        'changePct': 57.2,
      },
    ],
    'GET /products/p1': {
      'id': 'p1',
      'name': 'Ayçiçek yağı',
      'sizeLabel': '5 litre',
      'observations': 14,
      'merchantCount': 4,
      'monthSpan': 11,
      'changePct': 57.2,
      'firstPackPrice': 248.0,
      'lastPackPrice': 389.9,
      'history': [
        {'date': '2025-09-12', 'unitPrice': 49.6, 'packPrice': 248.0},
        {'date': '2026-01-15', 'unitPrice': 58.76, 'packPrice': 293.8},
        {'date': '2026-08-14', 'unitPrice': 77.98, 'packPrice': 389.9},
      ],
      'byMerchant': [
        {
          'merchant': 'BİM',
          'packPrice': 359.0,
          'unitPrice': 71.8,
          'seenOn': '2026-08-01',
        },
        {
          'merchant': 'Migros',
          'packPrice': 389.9,
          'unitPrice': 77.98,
          'seenOn': '2026-08-14',
        },
      ],
    },
  };
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.routes);

  final Map<String, Object?> routes;
  final List<String> calls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = '${request.method} ${request.url.path}';
    calls.add(key);
    final body = routes[key];
    final status = body == null ? 404 : 200;
    final payload = jsonEncode(body ?? {'error': 'Bulunamadı'});
    return http.StreamedResponse(
      Stream.value(utf8.encode(payload)),
      status,
      request: request,
      // Sunucu charset göndermezse ne olduğunu testte de görelim: başlık
      // bilerek eksik. İstemci baytları kendisi UTF-8 çözüyor.
    );
  }
}
