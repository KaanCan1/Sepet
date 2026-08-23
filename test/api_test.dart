import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sepet/data/api.dart';

/// Çağrı sırasına göre farklı davranan istemci.
class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.steps);

  /// Her adım ya bir gecikme ya da bir cevap üretiyor.
  final List<Future<http.StreamedResponse> Function()> steps;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final step = steps[calls.clamp(0, steps.length - 1)];
    calls++;
    return step();
  }
}

http.StreamedResponse _json(int status, Object body) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status);

/// Asla dönmeyen çağrı — zaman aşımını tetikler.
Future<http.StreamedResponse> _hangs() =>
    Completer<http.StreamedResponse>().future;

void main() {
  Api build(_ScriptedClient client) => Api(
    client: client,
    baseUrl: 'http://ornek',
    timeout: const Duration(milliseconds: 30),
    wakeTimeout: const Duration(milliseconds: 200),
  );

  group('Api uyandırma denemesi', () {
    // Render ücretsiz katmanda servisi uyutuyor; ilk istek onu uyandırırken
    // 30-60 saniye sürüyor. Tek ve kısa zaman aşımıyla uygulama sunucu daha
    // açılmadan pes ediyor ve kullanıcıya "bağlantını kontrol et" diyerek
    // yanlış yere baktırıyordu.
    test('ilk istek zaman aşımına uğrarsa bir kez daha deniyor', () async {
      final client = _ScriptedClient([
        _hangs,
        () async => _json(200, {'ok': true}),
      ]);

      final result = await build(client).get('/health');

      expect(client.calls, 2, reason: 'ikinci deneme yapılmalıydı');
      expect(result, {'ok': true});
    });

    test('ikisi de zaman aşımına uğrarsa uyanma ihtimalini söylüyor', () async {
      final client = _ScriptedClient([_hangs]);

      await expectLater(
        build(client).get('/health'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'mesaj',
            contains('uyanıyor'),
          ),
        ),
      );
      expect(client.calls, 2);
    });

    // Sunucu cevap verdiyse — reddetse bile — tekrar denemenin anlamı yok.
    test(
      'sunucu reddettiğinde tekrar denemiyor, kendi mesajını gösteriyor',
      () async {
        final client = _ScriptedClient([
          () async => _json(403, {'error': 'Bu adres için giriş açık değil'}),
        ]);

        await expectLater(
          build(client).post('/auth/dev-login', {'email': 'kim@ornek.com'}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'durum', 403)
                .having(
                  (e) => e.message,
                  'mesaj',
                  'Bu adres için giriş açık değil',
                ),
          ),
        );
        expect(client.calls, 1, reason: 'reddedilen istek tekrarlanmamalı');
      },
    );

    test('ağ yoksa beklemeden bildiriyor', () async {
      final client = _ScriptedClient([
        () async => throw const SocketException('ağ yok'),
      ]);

      await expectLater(
        build(client).get('/index'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'mesaj',
            contains('ulaşılamadı'),
          ),
        ),
      );
      expect(client.calls, 1);
    });
  });
}
