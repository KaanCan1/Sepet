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
  Api({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'SEPET_API_URL',
            defaultValue: 'http://localhost:4000',
          );

  final http.Client _client;
  final String baseUrl;

  String? _token;

  // ignore: use_setters_to_change_properties
  void setToken(String? token) => _token = token;

  static const _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (_token != null) 'authorization': 'Bearer $_token',
  };

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    late final http.Response res;
    try {
      res = await run().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('Sunucu yanıt vermedi. Bağlantını kontrol et.');
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

  Future<dynamic> get(String path) =>
      _send(() => _client.get(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) => _send(
    () => _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );
}
