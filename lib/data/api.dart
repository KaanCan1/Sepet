import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Sunucudan dönen hata. Mesaj kullanıcıya gösterilebilir olmalı.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// Oturum düştü — çağıranın giriş ekranına dönmesi gerekiyor.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Sepet sunucusuna konuşan ince istemci.
///
/// Adres derleme zamanında veriliyor:
///   flutter run --dart-define=SEPET_API_URL=https://...
/// Varsayılan iOS simülatöründen çalışan yerel sunucu.
class Api {
  Api({
    http.Client? client,
    String? baseUrl,
    Duration? timeout,
    Duration? wakeTimeout,
  }) : _client = client ?? http.Client(),
       _timeout = timeout ?? const Duration(seconds: 12),
       _wakeTimeout = wakeTimeout ?? const Duration(seconds: 50),
       baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'SEPET_API_URL',
             defaultValue: 'http://localhost:4000',
           );

  final http.Client _client;
  final String baseUrl;

  String? _token;

  void setToken(String? token) {
    _token = token;
    // Kimlik değişti: uçuştaki cevaplar artık başka birine ait.
    _inflight.clear();
  }

  /// Uçuştaki GET istekleri, yol -> cevap. Aynı yol iki kez istenirse ikinci
  /// çağrı birincinin cevabını bekliyor.
  ///
  /// Açılışta bunun somut karşılığı var: endeks ekranı da fişler sekmesi de
  /// `/receipts` istiyor ve ikisi birlikte yükleniyor. Sunucu aynı yanıtı iki
  /// kez hesaplıyordu. Yalnızca GET: gövdeli yöntemler yan etkili, birinin
  /// yerine ötekinin cevabı verilemez.
  final Map<String, Future<dynamic>> _inflight = {};

  /// İlk deneme. Uyanık bir sunucu bunun çok altında cevap veriyor.
  final Duration _timeout;

  /// İkinci deneme. Render ücretsiz katmanda 15 dakika sessizlikten sonra
  /// servisi uyutuyor ve uyanması 30-60 saniye sürüyor — üstelik başlatma
  /// komutumuz her uyanışta migration'ları ve katalog yüklemesini de
  /// çalıştırıyor. Tek ve kısa bir zaman aşımıyla uygulama sunucu daha
  /// açılmadan pes ediyordu; kullanıcıya da "bağlantını kontrol et" diyerek
  /// yanlış yere baktırıyordu.
  /// Testler bu iki süreyi milisaniyeye indiriyor.
  final Duration _wakeTimeout;

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (_token != null) 'authorization': 'Bearer $_token',
  };

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    late final http.Response res;
    try {
      res = await _runWithWakeRetry(run);
    } on TimeoutException {
      throw const ApiException(
        'Sunucu yanıt vermedi. Uyku modundan uyanıyor olabilir; '
        'birkaç saniye sonra yeniden dene.',
      );
    } on SocketException {
      throw const ApiException('Sunucuya ulaşılamadı. Bağlantını kontrol et.');
    }

    // res.body, Content-Type'ta charset yoksa latin-1 varsayıyor ve Türkçe
    // karakterleri bozuyor ("TÜİK" -> "TÃÄ°K"). Baytları doğrudan UTF-8
    // olarak çözüyoruz — sunucunun başlığına bağlı kalmıyoruz.
    final text = res.bodyBytes.isEmpty ? '' : utf8.decode(res.bodyBytes);
    final body = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final message = body is Map && body['error'] is String
        ? body['error'] as String
        : 'Beklenmeyen bir hata oldu (${res.statusCode})';
    throw ApiException(message, statusCode: res.statusCode);
  }

  /// Zaman aşımında bir kez daha, bu sefer uzun süreyle dener.
  ///
  /// Yeniden deneme yalnızca zaman aşımına özel: sunucu cevap verdiyse
  /// — reddetse bile — tekrar denemenin anlamı yok. Bağlantı hatasında da
  /// beklemenin faydası yok, o hemen bildiriliyor.
  Future<http.Response> _runWithWakeRetry(
    Future<http.Response> Function() run,
  ) async {
    try {
      return await run().timeout(_timeout);
    } on TimeoutException {
      return run().timeout(_wakeTimeout);
    }
  }

  Future<dynamic> get(String path) {
    final running = _inflight[path];
    if (running != null) return running;
    final future = _send(
      () => _client.get(Uri.parse('$baseUrl$path'), headers: _headers),
    );
    _inflight[path] = future;
    // Kayıt cevap gelince siliniyor; sonraki çağrı yeniden sunucuya gidiyor.
    // Bu bir önbellek değil, yalnızca eşzamanlı isteklerin birleştirilmesi.
    return future.whenComplete(() => _inflight.remove(path));
  }

  Future<dynamic> put(String path, [Object? body]) => _send(
    () => _client.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> delete(String path) => _send(
    () => _client.delete(Uri.parse('$baseUrl$path'), headers: _headers),
  );

  Future<dynamic> post(String path, [Object? body]) => _send(
    () => _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );
}
