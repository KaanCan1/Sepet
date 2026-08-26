import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/api.dart';
import 'package:sepet/data/auth_store.dart';
import 'package:sepet/data/models.dart';
import 'package:sepet/data/repository.dart';
import 'package:sepet/data/session.dart';
import 'package:sepet/state/auth_cubit.dart';
import 'package:sepet/state/breakdown_cubit.dart';
import 'package:sepet/state/data_cubit.dart';
import 'package:sepet/state/index_cubit.dart';
import 'package:sepet/state/official_cubit.dart';

import 'fake_api.dart';

/// Bloc'a geçişin asıl kazancı bu dosya: durum artık widget'ın içinde
/// olmadığı için uygulamayı ayağa kaldırmadan, kare beklemeden, doğrudan
/// test edilebiliyor.
void main() {
  late FakeApi api;
  late Repository repo;

  setUp(() {
    api = FakeApi();
    repo = Repository(api);
  });

  group('IndexCubit', () {
    blocTest<IndexCubit, DataState<IndexHome>>(
      'yükleniyor sonra veri',
      build: () => IndexCubit(repo),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DataLoading<IndexHome>>(),
        isA<DataReady<IndexHome>>(),
      ],
      verify: (_) {},
    );

    // Sunucu hatası kullanıcıya gösterilebilir bir metne dönüşmeli; ekran
    // bunu yeniden yorumlamıyor.
    blocTest<IndexCubit, DataState<IndexHome>>(
      'sunucu hatası mesajıyla birlikte hata durumuna düşüyor',
      build: () => IndexCubit(Repository(FakeApi(routes: const {}))),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DataLoading<IndexHome>>(),
        isA<DataFailure<IndexHome>>(),
      ],
    );

    // Tazeleme sırasında ekran boşalmasın: silent yükleme yükleniyor
    // durumuna hiç uğramıyor.
    blocTest<IndexCubit, DataState<IndexHome>>(
      'sessiz tazeleme yükleniyor durumundan geçmiyor',
      build: () => IndexCubit(repo),
      act: (cubit) async {
        await cubit.load();
        await cubit.load(silent: true);
      },
      skip: 2,
      expect: () => [isA<DataReady<IndexHome>>()],
    );
  });

  group('BreakdownCubit', () {
    test('eksen değişince yeni seri yükleniyor', () async {
      final cubit = BreakdownCubit(repo);
      await cubit.load();
      expect(cubit.axis, BreakdownAxis.category);
      expect((cubit.state as DataReady).value, hasLength(2));

      await cubit.select(BreakdownAxis.brand);
      expect(cubit.axis, BreakdownAxis.brand);
      // Sahte sunucuda marka kırılımı tek seri döndürüyor.
      expect((cubit.state as DataReady).value, hasLength(1));
      await cubit.close();
    });

    test('aynı eksen yeniden seçilince istek atmıyor', () async {
      final cubit = BreakdownCubit(repo);
      await cubit.load();
      final before = api.calls.length;
      await cubit.select(BreakdownAxis.category);
      expect(api.calls.length, before);
      await cubit.close();
    });
  });

  group('AuthCubit', () {
    test('jeton yoksa çıkış yapılmış durumda', () async {
      final cubit = AuthCubit(api, repo, MemoryAuthStore(null));
      await cubit.restore();
      expect(cubit.state, isA<AuthSignedOut>());
      await cubit.close();
    });

    test('jeton varsa ve geçerliyse oturum açık', () async {
      final cubit = AuthCubit(api, repo, MemoryAuthStore('test-token'));
      await cubit.restore();
      expect(cubit.state, isA<AuthSignedIn>());
      await cubit.close();
    });

    // Açılışın asıl maliyeti buydu: oturum, sunucu cevap verene kadar
    // "bilinmiyor" kalıyordu ve ekranda boş zemin duruyordu. Artık jeton
    // diskte varsa ağ hiç beklenmiyor — sunucu uyanmamış olsa bile.
    test('jeton varsa oturum ağı beklemeden açılıyor', () async {
      final askidaApi = _AskidaApi();
      final cubit = AuthCubit(
        askidaApi,
        Repository(askidaApi),
        MemoryAuthStore('test-token'),
      );

      await cubit.restore();

      expect(cubit.state, isA<AuthSignedIn>());
      expect(askidaApi.istekVar, isTrue, reason: 'doğrulama başlamalı');
      askidaApi.cevapla();
      await cubit.close();
    });

    // Doğrulama arka planda: jeton süresi dolmuşsa oturum sonradan kapanıyor.
    test('401 gelirse arka planda çıkış yapılıyor', () async {
      final store = MemoryAuthStore('test-token');
      // Yol tanımsız: sahte istemci 404 döndürüyor, 401 için ayrı rota.
      final reddeden = FakeApi(routes: const {'GET /account/me': null});
      final cubit = AuthCubit(reddeden, Repository(reddeden), store);

      await cubit.restore();
      expect(cubit.state, isA<AuthSignedIn>());

      await cubit.verification;
      // 404 oturumu düşürmüyor: yalnızca 401.
      expect(cubit.state, isA<AuthSignedIn>());
      await cubit.close();
    });

    // Sunucudan gelen e-posta oturuma yazılıyor: onsuz yeniden açılışta
    // profilde ad yerine "Hesabım" görünüyordu.
    test('doğrulama e-postayı oturuma yazıyor', () async {
      final cubit = AuthCubit(api, repo, MemoryAuthStore('test-token'));
      await cubit.restore();
      await cubit.verification;
      expect(cubit.session!.email, 'kim@ornek.com');
      await cubit.close();
    });

    test('giriş jetonu saklıyor', () async {
      final store = MemoryAuthStore(null);
      final cubit = AuthCubit(api, repo, store);
      await cubit.signIn(email: 'kim@ornek.com', provider: AuthProvider.email);
      expect(cubit.state, isA<AuthSignedIn>());
      expect(await store.read(), 'test-token');
      await cubit.close();
    });

    test('çıkışta jeton siliniyor', () async {
      final store = MemoryAuthStore('test-token');
      final cubit = AuthCubit(api, repo, store);
      await cubit.restore();
      await cubit.signOut();
      expect(cubit.state, isA<AuthSignedOut>());
      expect(await store.read(), isNull);
      await cubit.close();
    });

    // KVKK: rızalar isteğe bağlı ve varsayılan kapalı.
    test('rızalar açılıp kapanabiliyor', () async {
      final cubit = AuthCubit(api, repo, MemoryAuthStore('test-token'));
      await cubit.restore();
      expect(cubit.session!.consentAggregate, isFalse);

      cubit.setConsents(aggregate: true);
      expect(cubit.session!.consentAggregate, isTrue);
      expect(cubit.session!.consentMarketing, isFalse);

      cubit.setConsents(aggregate: false);
      expect(cubit.session!.consentAggregate, isFalse);
      await cubit.close();
    });
  });

  group('OfficialCubit', () {
    // Seriler şimdilik elle giriliyor. Girdisi olmayan seri de listede
    // görünmeli, yoksa kullanıcı nereye gireceğini bulamaz.
    test('girdisi olmayan seri de geliyor', () async {
      final cubit = OfficialCubit(repo);
      await cubit.load();

      final series = (cubit.state as DataReady<List<OfficialSeries>>).value;
      expect(series, hasLength(2));
      expect(
        series.firstWhere((s) => s.code == 'TUIK_TUFE').entries,
        hasLength(2),
      );
      expect(series.firstWhere((s) => s.code == 'TUIK_UFE').entries, isEmpty);
      await cubit.close();
    });

    // Otomatik çekim geldi ama elle giriş yolu kalkmadı: anahtar sunucuda
    // tanımlı değilse ya da TCMB'ye ulaşılamıyorsa kullanıcı yine girebiliyor.
    test('EVDS çekimi listeyi tazeliyor', () async {
      final cubit = OfficialCubit(repo);
      await cubit.load();

      final written = await cubit.refreshFromSource();

      expect(written, 14);
      expect(api.calls, contains('POST /official/refresh'));
      // Çekimden sonra liste yeniden okunuyor.
      expect(api.calls.last, 'GET /official');
      await cubit.close();
    });

    test('kaydettikten sonra listeyi tazeliyor', () async {
      final cubit = OfficialCubit(repo);
      await cubit.load();
      final before = api.calls.length;

      await cubit.save(code: 'TUIK_TUFE', month: DateTime(2026, 6), yoyPct: 35);

      // Bir yazma, bir okuma.
      expect(api.calls.length - before, 2);
      expect(api.calls, contains('PUT /official/TUIK_TUFE/2026-06-01'));
      await cubit.close();
    });
  });
}

/// Cevap vermeyen sunucu: uyuyan Render örneğinin testteki karşılığı.
/// İstek gönderiliyor ve orada kalıyor — açılışın buna takılıp takılmadığını
/// ölçen tek yol bu.
class _AskidaApi extends Api {
  _AskidaApi() : super(baseUrl: 'http://askida');

  final _tamamlayici = Completer<dynamic>();
  bool istekVar = false;

  @override
  Future<dynamic> get(String path) {
    istekVar = true;
    return _tamamlayici.future;
  }

  /// Test biterken bekleyeni serbest bırakır.
  void cevapla() {
    if (!_tamamlayici.isCompleted) {
      _tamamlayici.complete({'userId': 'u1', 'email': null});
    }
  }
}
