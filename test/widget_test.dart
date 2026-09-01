import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/app_scope.dart';
import 'package:sepet/data/auth_store.dart';
import 'package:sepet/data/fmt.dart';
import 'package:sepet/data/notifications.dart';
import 'package:sepet/data/receipt_parser.dart';
import 'package:sepet/screens/draft_receipt_screen.dart';
import 'package:sepet/screens/root_gate.dart';
import 'package:sepet/screens/shell.dart';
import 'package:sepet/screens/welcome_screen.dart';
import 'package:sepet/widgets/atoms.dart';
import 'package:sepet/widgets/chart.dart';

import 'fake_api.dart';

/// Uygulamayı sahte sunucuyla kurar.
Widget bootstrap({String? token, FakeApi? api}) => AppScope(
  api: api ?? FakeApi(),
  authStore: MemoryAuthStore(token),
  reminder: MemoryMonthlyReminder(),
  child: MaterialApp(locale: const Locale('tr', 'TR'), home: const RootGate()),
);

void main() {
  // Oturum artık global bir bildirici değil, AuthCubit'te — her test kendi
  // ağacını kurduğu için sıfırlamaya gerek kalmadı.
  group('Fmt', () {
    test('binlik ayracı nokta, ondalık virgül', () {
      expect(Fmt.money(1917.45), '1.917,45');
      expect(Fmt.money(842.6), '842,60');
    });

    test('miktar gereksiz sıfır yazmaz', () {
      expect(Fmt.quantity(3), '3');
      expect(Fmt.quantity(1.24), '1,240');
      expect(Fmt.quantity(0.5), '0,500');
    });

    test('yüzdeler işaretiyle', () {
      expect(Fmt.pct1(47.2), '47,2%');
      expect(Fmt.signedPct1(-6.2), '−6,2%');
      expect(Fmt.signedPct0(57.2), '+57%');
    });

    test('tarih kısaltması Türkçe', () {
      expect(Fmt.dayMonth(DateTime(2026, 8, 18)), '18 AĞU');
      expect(Fmt.monthLong(DateTime(2026, 8, 18)), 'Ağustos');
    });
  });

  group('Kök geçidi', () {
    testWidgets('jeton yoksa karşılama ekranı çıkar', (tester) async {
      await tester.pumpWidget(bootstrap());
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Apple ile Giriş Yap'), findsOneWidget);
      expect(find.text('Google ile oturum aç'), findsOneWidget);
      // Giriş zorunlu: hesapsız devam yolu yok.
      expect(find.textContaining('hesapsız'), findsNothing);
    });

    testWidgets('geçerli jetonla doğrudan kabuğa girer', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.byType(Shell), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  });

  group('Endeks ekranı', () {
    testWidgets('manşet ve pencere sunucudan geliyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      // BigNumber zengin metin kullanıyor; find.text görmüyor.
      final big = tester.widget<BigNumber>(find.byType(BigNumber));
      expect(big.value, '20,8');
      // 12 ay dolmadıysa etiket gerçek pencereyi söylüyor.
      expect(find.text('SON 2 AY'), findsOneWidget);
      expect(find.text('SON 12 AY'), findsNothing);
    });

    testWidgets('resmî veri yoksa tire gösteriliyor, uydurulmuyor', (
      tester,
    ) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.text('TÜİK TÜFE'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      // Eksik seri adıyla söylenmeli. Eski metin "henüz çekilmedi" diyordu:
      // hem yanlış (çekilmiyorlar, elle giriliyorlar) hem de biri girildikten
      // sonra bile aynı kalıyordu.
      expect(find.textContaining('elle giriliyor'), findsOneWidget);
    });

    testWidgets('son fişler bekleyen eşleşmeyi gösteriyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 EŞLEŞME'), findsWidgets);
    });
  });

  // Fişini silen ya da yeni giren kullanıcı bomboş bir ekranla karşılaşıyor
  // ve ne yapacağını göremiyordu. Boş durumun üç şeyi taşıması gerekiyor:
  // yapılacak iş, tek bir birincil eylem ve zaten bağımsız olan
  // karşılaştırma çizgisi.
  group('İlk açılış', () {
    Widget emptyApp() => AppScope(
      api: FakeApi(
        routes: {
          ...FakeApi.defaultRoutes,
          'GET /index': {
            'headline': null,
            'series': <Object>[],
            'official': [
              {
                'code': 'TUIK_TUFE',
                'publisher': 'TÜİK',
                'name': 'TÜFE',
                'isOfficial': true,
                'yoyPct': 34.1,
              },
            ],
          },
          'GET /receipts': <Object>[],
        },
      ),
      authStore: MemoryAuthStore('test-token'),
      reminder: MemoryMonthlyReminder(),
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        home: const RootGate(),
      ),
    );

    testWidgets('fiş yokken yapılacak iş ve eylem görünüyor', (tester) async {
      await tester.pumpWidget(emptyApp());
      await tester.pumpAndSettle();

      expect(find.text('İlk fişini ekle'), findsOneWidget);
      expect(find.text('Fiş çek'), findsOneWidget);
      expect(find.textContaining('cihazından çıkmıyor'), findsOneWidget);
    });

    testWidgets('fiş yokken bile TÜİK sayısı görünüyor', (tester) async {
      await tester.pumpWidget(emptyApp());
      await tester.pumpAndSettle();

      // Resmî seri kullanıcının verisine bağlı değil; sunucu endeksi
      // olmayan hesapta da gönderiyor.
      expect(find.text('TÜİK TÜFE'), findsOneWidget);
      expect(find.text('34,1%'), findsOneWidget);
    });

    testWidgets('kamera düğmesi kabukta duruyor', (tester) async {
      await tester.pumpWidget(emptyApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan-button')), findsOneWidget);
    });
  });

  // TÜİK her zaman YILLIK açıklıyor. Kullanıcının penceresi 12 ay dolmadan
  // daha kısa ve ekran bir süre ikisini doğrudan çıkarıyordu: bir ayda %17
  // artan sepet için "TÜİK'in 17,1 puan altında" yazıyordu. Rakam doğru
  // çıkarma işlemiydi ama cümle yanlıştı — o sepet resmî ölçümün kat kat
  // üstünde artıyor.
  group('Pencere kıyası', () {
    Widget appWith({required int windowMonths, double? yoyPct = 34.1}) =>
        AppScope(
          api: FakeApi(
            routes: {
              ...FakeApi.defaultRoutes,
              'GET /index': {
                'headline': {
                  'changePct': 17.0,
                  'windowMonths': windowMonths,
                  'monthDeltaPoints': null,
                  'coveredWeight': 1,
                },
                'series': [
                  {'month': '2026-07-01', 'level': 100, 'momPct': 0},
                  {'month': '2026-08-01', 'level': 117, 'momPct': 17},
                ],
                'official': [
                  {
                    'code': 'TUIK_TUFE',
                    'publisher': 'TÜİK',
                    'name': 'TÜFE',
                    'isOfficial': true,
                    'yoyPct': yoyPct,
                  },
                ],
              },
            },
          ),
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        );

    testWidgets('12 ay dolmadan fark yazılmıyor', (tester) async {
      await tester.pumpWidget(appWith(windowMonths: 1));
      await tester.pumpAndSettle();

      // TÜİK sayısı duruyor — saklamıyoruz.
      expect(find.text('34,1%'), findsOneWidget);
      // Ama çıkarma işlemi yok.
      expect(find.textContaining('PUAN ALTINDA'), findsNothing);
      expect(find.textContaining('PUAN ÜSTÜNDE'), findsNothing);
      // Yerine neyin neyle kıyaslanamadığı yazıyor.
      expect(find.text('YILLIK'), findsOneWidget);
      expect(find.textContaining('kıyaslamak için 12 ay'), findsOneWidget);
    });

    testWidgets('12 ay dolunca fark yazılıyor', (tester) async {
      await tester.pumpWidget(appWith(windowMonths: 12));
      await tester.pumpAndSettle();

      // 34,1 − 17,0 = 17,1
      expect(find.text('17,1 PUAN ALTINDA'), findsOneWidget);
      expect(find.textContaining('kıyaslamak için 12 ay'), findsNothing);
    });

    // Aynı kök hata kartta da vardı ve orası daha ağır basıyor: kart
    // paylaşılmak için var, yani yanlış eşleştirilmiş iki sayı kullanıcının
    // adına başkasına gösteriliyor demek.
    testWidgets('kart 12 ay dolmadan "aynı dönem" demiyor', (tester) async {
      await tester.pumpWidget(appWith(windowMonths: 1));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('kartı'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aynı dönemde'), findsNothing);
      expect(find.textContaining('Seninki 1 aylık'), findsOneWidget);
      expect(find.textContaining('TÜİK yıllık 34,1%'), findsOneWidget);
    });

    testWidgets('kart 12 ay dolunca aynı dönem diyor', (tester) async {
      await tester.pumpWidget(appWith(windowMonths: 12));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('kartı'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aynı dönemde TÜİK 34,1%'), findsOneWidget);
    });
  });

  // Manşetteki yıllık yüzde grafiğe çizilemiyor: yıllık değişim serisinden
  // aylık bir yol geri türetilemez. Kesikli TÜİK çizgisi ay ay seviyeden
  // çiziliyor ve iki seri ortak aya 100'leniyor — TÜİK'in taban yılı
  // (2025=100) ekranda hiç görünmüyor.
  group('TÜİK çizgisi', () {
    Widget appWith({required Map<String, double> levels}) => AppScope(
      api: FakeApi(
        routes: {
          ...FakeApi.defaultRoutes,
          'GET /index': {
            'headline': {
              'changePct': 17.0,
              'windowMonths': 3,
              'monthDeltaPoints': null,
              'coveredWeight': 1,
            },
            'series': [
              {'month': '2026-05-01', 'level': 100, 'momPct': 0},
              {'month': '2026-06-01', 'level': 108, 'momPct': 8},
              {'month': '2026-07-01', 'level': 113, 'momPct': 4.6},
              {'month': '2026-08-01', 'level': 117, 'momPct': 3.5},
            ],
            'official': [
              {
                'code': 'TUIK_TUFE',
                'publisher': 'TÜİK',
                'name': 'TÜFE',
                'isOfficial': true,
                'yoyPct': 34.1,
                'levels': [
                  for (final e in levels.entries)
                    {'month': e.key, 'level': e.value},
                ],
              },
            ],
          },
        },
      ),
      authStore: MemoryAuthStore('test-token'),
      reminder: MemoryMonthlyReminder(),
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        home: const RootGate(),
      ),
    );

    List<ChartSeries> serilerinden(WidgetTester tester) =>
        tester.widget<LineChart>(find.byType(LineChart).first).series;

    testWidgets('seviye varsa ikinci çizgi kesikli çiziliyor', (tester) async {
      await tester.pumpWidget(
        appWith(
          levels: {
            '2026-05-01': 120.0,
            '2026-06-01': 124.0,
            '2026-07-01': 128.0,
            '2026-08-01': 132.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      final seriler = serilerinden(tester);
      expect(seriler, hasLength(2));
      expect(seriler[1].dashed, isTrue);

      // İkisi de ortak ilk aya 100'lenmiş: TÜİK'in ham 120'si ekranda yok.
      expect(seriler[0].values.first, closeTo(100, 0.001));
      expect(seriler[1].values.first, closeTo(100, 0.001));
      // 132 / 120 = 1,10
      expect(seriler[1].values.last, closeTo(110, 0.001));
    });

    // TÜİK içinde bulunulan ayı genelde henüz açıklamamış olur.
    testWidgets('açıklanmamış ay boş kalıyor, uzatılmıyor', (tester) async {
      await tester.pumpWidget(
        appWith(
          levels: {
            '2026-05-01': 120.0,
            '2026-06-01': 124.0,
            '2026-07-01': 128.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      final seriler = serilerinden(tester);
      expect(seriler, hasLength(2));
      // Kullanıcının serisiyle aynı uzunlukta — hizalama bozulmuyor.
      expect(seriler[1].values, hasLength(4));
      // Son ay boş: komşusuna bağlanmadı.
      expect(seriler[1].values.last, isNull);
    });

    testWidgets('tek seviye varsa çizgi hiç çizilmiyor', (tester) async {
      await tester.pumpWidget(appWith(levels: {'2026-05-01': 120.0}));
      await tester.pumpAndSettle();

      // Tek nokta eğim göstermez.
      expect(serilerinden(tester), hasLength(1));
    });

    testWidgets('seviye yoksa tek çizgi kalıyor', (tester) async {
      await tester.pumpWidget(appWith(levels: const {}));
      await tester.pumpAndSettle();

      expect(serilerinden(tester), hasLength(1));
    });
  });

  group('Fiş detayı', () {
    testWidgets('eşleşmemiş satır işaretli, eşleşen değil', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      // Kırılım kartı eklendikten sonra fiş listesi aşağı kaydı ve satır
      // yüzen sekme çubuğunun altında kalıyordu; dokunuş sessizce ıskalıyordu.
      // scrollUntilVisible işe yaramıyor çünkü satır zaten ağaçta — sorun
      // görünürlük değil, üstünü kapatan çubuk.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();

      expect(find.text('Süt, tam yağlı 1 litre'), findsOneWidget);
      // Durum artık şeritle ve tek satırlık ipucuyla veriliyor; üstteki
      // sayaç da tek dokunuşta hepsini gezen akışı açıyor.
      expect(find.text('eşleşme bekliyor'), findsOneWidget);
      expect(find.text('1 kalem eşleşme bekliyor'), findsOneWidget);
      expect(find.text('SIRAYLA ÇÖZ'), findsOneWidget);
      // Kasa poşeti sessiz: endeks dışı, sorulmuyor.
      expect(find.text('endeks dışı'), findsOneWidget);
    });

    // Fiş "116,70" basıyor ama "38,90 / litre" basmıyor — ve paketler
    // farklı boyda olduğu için karşılaştırılabilir tek fiyat bu. Endeks
    // olgunlaşmasa da kullanıcının ilk fişinde eline geçen yeni bilgi.
    // Fiş tarihi bir gün geriden görünüyordu. Sahte yol sunucunun bugünkü
    // biçimini taşıyor ("2026-08-18", saatsiz); ekrandaki gün ona eşit
    // olmalı — arada saat dilimi girerse bu kırılır.
    testWidgets('fiş tarihi yazılan günü gösteriyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('18 AĞU 2026'), findsOneWidget);
    });

    testWidgets('eşleşmiş satırda birim fiyat yazıyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(find.text('38,90 / litre'), findsOneWidget);
      // Eşleşmemiş satırda uydurulmuyor: sayı gözlemden geliyor, satırdan
      // hesaplanmıyor.
      expect(find.textContaining(' / adet'), findsNothing);
    });

    testWidgets('gramaj belirsizse yalnızca boy soruluyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();

      // Satırlar kâğıt fişin altında; ekranı aşağı çekmeden dokunulamıyor.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(find.text('eşleşme bekliyor'));
      await tester.pumpAndSettle();

      // Marka ve ürün zaten çözülmüş: arama kutusu çıkmıyor.
      expect(find.text('HANGİ BOY?'), findsOneWidget);
      expect(find.text('Katalogda ara'), findsNothing);

      // Her boyun yanında o seçim yapılırsa endekse girecek birim fiyat.
      // 184,50 TL / 15 adet = 12,30 · / 30 adet = 6,15.
      expect(find.text("15'li"), findsOneWidget);
      expect(find.text("30'lu"), findsOneWidget);
      expect(find.textContaining('12,30'), findsOneWidget);
      expect(find.textContaining('6,15'), findsOneWidget);

      // Katalogda olmayan gramaj elle girilebiliyor.
      expect(find.text('Listede yok, gramajı kendim gireyim'), findsOneWidget);
    });

    // Fişte yazan ile satın alınan her zaman aynı şey değil: "TACIROGLU SUT"
    // satırı aslında kaşar peyniri olabiliyor. Kullanıcı gram girdiğinde
    // yanlış olan birim değil grup — 400 g'ı litre cinsinden bir grupta
    // saklamak endeksin birimini bozar. O yüzden boyut değişince grup da
    // soruluyor ve seçilmeden kaydetmeye izin verilmiyor.
    testWidgets('birim boyutu değişince ürün grubu soruluyor', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(bootstrap(token: 'test-token', api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(find.text('eşleşme bekliyor'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Listede yok, gramajı kendim gireyim'));
      await tester.pumpAndSettle();

      // Grubun kendi boyutu (adet) başta, ama diğer birimler de burada.
      expect(find.text('adet'), findsWidgets);
      expect(find.text('kg'), findsOneWidget);

      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();

      // Boyut değişti: grup soruluyor ve kaydetme kilitli.
      expect(api.calls, contains('GET /products/catalog/groups'));
      expect(find.textContaining('başka bir grupta'), findsOneWidget);
      expect(find.text('Önce ürün grubunu seç'), findsOneWidget);

      // İlk alan gramaj, ikincisi grup araması.
      await tester.enterText(find.byType(TextField).first, '400');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beyaz peynir').last);
      await tester.pumpAndSettle();

      // Düğme kataloğa girecek adı yazıyor; onay o isme veriliyor.
      final ekle = find.text('Beyaz peynir olarak ekle');
      expect(ekle, findsOneWidget);
      await tester.ensureVisible(ekle);
      await tester.pumpAndSettle();
      await tester.tap(ekle);
      await tester.pumpAndSettle();

      expect(api.calls, contains('POST /products/catalog'));
    });
  });

  // Katalog ne kadar büyürse büyüsün kuyruk bitmiyor: rafta on binlerce
  // kalem var. Bu ekran olmadan katalogda bulunmayan bir kalemin tek çaresi
  // yanlış bir ürün seçmek (endeksi bozar) ya da satırı sonsuza kadar
  // bekletmekti (kapsamı daraltır).
  group('Yeni ürün tanımlama', () {
    Future<void> ac(WidgetTester tester, FakeApi api) async {
      await tester.pumpWidget(
        AppScope(
          api: api,
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(find.text('eşleşme bekliyor'));
      await tester.pumpAndSettle();
    }

    testWidgets('katalogda yoksa tanımlama açılıyor', (tester) async {
      final api = FakeApi();
      await ac(tester, api);

      // Sahte yolda boy sorusu geliyor; önce ürün sorusuna geçiliyor.
      await tester.tap(find.text('Bu ürün değil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aradığım ürün katalogda yok'));
      await tester.pumpAndSettle();

      expect(find.text('YENİ ÜRÜN'), findsOneWidget);
      expect(find.text('KATEGORİ'), findsOneWidget);
      expect(api.calls, contains('GET /products/catalog/categories'));
    });

    testWidgets('eksik alanla kaydedilemiyor', (tester) async {
      final api = FakeApi();
      await ac(tester, api);
      await tester.tap(find.text('Bu ürün değil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aradığım ürün katalogda yok'));
      await tester.pumpAndSettle();

      // Kategori seçilmeden ve boy girilmeden düğme sunucuya gitmiyor:
      // eksik tanım endekse birimsiz bir kalem sokardı.
      await tester.tap(find.text('Kataloğa ekle'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('POST /products/catalog/define')));
    });

    testWidgets('tanım sunucuya gidiyor', (tester) async {
      final api = FakeApi();
      await ac(tester, api);
      await tester.tap(find.text('Bu ürün değil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aradığım ürün katalogda yok'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Çikolata');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Şeker ve tatlı'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '80');
      await tester.pumpAndSettle();

      // Birim ayrıca sorulmuyor; "80 g" yazan kullanıcı kilogram cinsinden
      // ölçtüğünü söylemiş oluyor. Birim fiyat da ona göre: 184,50 / 0,08.
      expect(find.textContaining('kg fiyatı'), findsOneWidget);

      await tester.tap(find.text('Kataloğa ekle'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /products/catalog/define'));
    });
  });

  // Hazır çarkı kullanmıyoruz: uygulamanın dili kâğıt fiş. Gösterge
  // çekildikçe açılan bir kesme çizgisi ve üstünde gidip gelen bir baskı
  // kafası; hâller etiketle de okunuyor.
  group('Aşağı çekerek yenileme', () {
    Widget app(FakeApi api) => AppScope(
      api: api,
      authStore: MemoryAuthStore('test-token'),
      reminder: MemoryMonthlyReminder(),
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        home: const RootGate(),
      ),
    );

    /// Parmak yolu, aşırı kaydırma pikseli değil: zıplayan fizik çekişi
    /// sönümlüyor ve eşik ekranda bunun iki katına denk geliyor.
    Future<TestGesture> cek(WidgetTester tester, double yol) async {
      final g = await tester.startGesture(const Offset(400, 200));
      // İlk adım kısa: dokunma eşiği onu yutuyor, kaydırma oradan
      // başlıyor. Sonrası eşit adımlar — tek büyük sıçrama aradaki
      // hâlleri hiç üretmiyor.
      var kalan = yol;
      final ilk = kalan < 30 ? kalan : 30.0;
      await g.moveBy(Offset(0, ilk));
      await tester.pump(const Duration(milliseconds: 16));
      kalan -= ilk;
      while (kalan > 0) {
        final adim = kalan < 60 ? kalan : 60.0;
        await g.moveBy(Offset(0, adim));
        await tester.pump(const Duration(milliseconds: 16));
        kalan -= adim;
      }
      return g;
    }

    testWidgets('çekme ilerledikçe hâl değişiyor', (tester) async {
      await tester.pumpWidget(app(FakeApi()));
      await tester.pumpAndSettle();

      // Durağan hâlde gösterge hiç kurulmuyor.
      expect(find.text('ÇEK'), findsNothing);

      final g = await cek(tester, 90);
      expect(find.text('ÇEK'), findsOneWidget);

      // Eşiği geçince bırakmaya davet ediyor.
      await g.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('BIRAK'), findsOneWidget);

      await g.up();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('bırakınca veri gerçekten yeniden çekiliyor', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      final oncesi = api.calls.where((c) => c == 'GET /index').length;

      final g = await cek(tester, 150);
      await g.up();
      await tester.pump(const Duration(seconds: 1));

      // Gösterge sahte bir animasyon değil: sunucuya gidiyor.
      expect(
        api.calls.where((c) => c == 'GET /index').length,
        greaterThan(oncesi),
      );
    });

    testWidgets('eşiğin altında bırakınca yenilenmiyor', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      final oncesi = api.calls.where((c) => c == 'GET /index').length;

      // Listeyi kaydırmak isteyen parmak yanlışlıkla tazelemeye düşmemeli.
      final g = await cek(tester, 60);
      await g.up();
      await tester.pump(const Duration(seconds: 1));

      expect(api.calls.where((c) => c == 'GET /index').length, oncesi);
    });
  });

  group('Fiş silme', () {
    // Önce kaydırmanın kendisi siliyordu ve onay ayrı bir uyarı
    // penceresinden isteniyordu. Şimdi kaydırma yalnızca kırmızı alanı
    // açıyor; silme oraya dokununca oluyor. Onay ayrı bir adım değil,
    // hareketin kendisi.
    testWidgets('kaydırmak silmiyor, sadece açıyor', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(
        AppScope(
          api: api,
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();

      await tester.drag(find.text('A101').first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Fiş yerinde duruyor ve sunucuya hiçbir şey gitmedi.
      expect(find.text('A101'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);
      expect(api.calls, isNot(contains('DELETE /receipts/r1')));
    });

    testWidgets('açık satıra dokunmak fişi açmıyor, kapatıyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.text('A101').first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Açıkken satır bir "kapat" düğmesi: kullanıcı vazgeçtiğinde geri
      // kaydırmak zorunda kalmasın ve yanlışlıkla fiş detayına düşmesin.
      await tester.tap(find.text('A101').first);
      await tester.pumpAndSettle();

      expect(find.text('SIRAYLA ÇÖZ'), findsNothing);
      expect(find.text('Sil'), findsNothing);
    });

    testWidgets('Sil e dokununca sunucuya gidiyor', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(
        AppScope(
          api: api,
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.text('A101').first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('DELETE /receipts/r1'));
      // Silinen fiş adıyla yazılıyor: işlem geri alınamıyor ve kullanıcının
      // hangisinin gittiğini görebilmesi tek güvencesi.
      expect(find.textContaining('A101 · 18 AĞU silindi'), findsOneWidget);
    });

    // Bir satır silinince kalanlar yukarı kayıyor ve kullanıcı hiç
    // kaydırmadığı bir satırda "Sil" görmemeli. Satırların fiş kimliğiyle
    // anahtarlanması da bunun için (bkz. receipts_screen.dart); test
    // anahtarı değil, kullanıcının gördüğü sonucu doğruluyor.
    testWidgets('silmeden sonra kalan satır kapalı', (tester) async {
      final r1 = {
        'id': 'r1',
        'merchant': 'A101',
        'purchasedAt': '2026-08-18',
        'total': 842.6,
        'itemCount': 11,
        'pendingCount': 2,
      };
      final r2 = {
        'id': 'r2',
        'merchant': 'BİM',
        'purchasedAt': '2026-08-11',
        'total': 310.0,
        'itemCount': 4,
        'pendingCount': 0,
      };
      final routes = <String, Object?>{
        ...FakeApi.defaultRoutes,
        'GET /receipts': [r1, r2],
      };

      await tester.pumpWidget(
        AppScope(
          api: FakeApi(routes: routes),
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.text('A101').first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Silme sonrası sunucu tek fiş döndürecek.
      routes['GET /receipts'] = [r2];
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('A101'), findsNothing);
      expect(find.text('BİM'), findsOneWidget);
      // Kalan satır kapalı: kullanıcı onu hiç kaydırmadı.
      expect(find.text('Sil'), findsNothing);
    });

    testWidgets('ikinci satır açılınca birincisi kapanıyor', (tester) async {
      await tester.pumpWidget(
        AppScope(
          api: FakeApi(
            routes: {
              ...FakeApi.defaultRoutes,
              'GET /receipts': [
                {
                  'id': 'r1',
                  'merchant': 'A101',
                  'purchasedAt': '2026-08-18',
                  'total': 842.6,
                  'itemCount': 11,
                  'pendingCount': 2,
                },
                {
                  'id': 'r2',
                  'merchant': 'BİM',
                  'purchasedAt': '2026-08-11',
                  'total': 310.0,
                  'itemCount': 4,
                  'pendingCount': 0,
                },
              ],
            },
          ),
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();

      await tester.drag(find.text('A101').first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('BİM').first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      // İki satır birden açıkken kullanıcının hangisine bastığı gözle
      // ayırt edilemiyor ve silme geri alınamıyor.
      expect(find.text('Sil'), findsOneWidget);
    });
  });

  group('Ürünler', () {
    testWidgets('liste ve geçmiş sunucudan geliyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('Ayçiçek yağı, 5 litre'), findsOneWidget);
      expect(find.text('+57%'), findsOneWidget);

      await tester.tap(find.text('Ayçiçek yağı, 5 litre'));
      await tester.pumpAndSettle();
      expect(find.text('SEPETİNDEKİ ÜRÜN'), findsOneWidget);
      expect(find.text('248,00'), findsOneWidget);
      expect(find.text('389,90'), findsWidgets);
    });

    // Satırın sağındaki kıvılcım listedeki geçmişten çiziliyor. Sunucu
    // önceden yalnızca ayrıntı ucunda geçmiş dönüyordu; liste boş gelince
    // kıvılcım hiç çizilmiyor, tasarımdaki yer boş kalıyordu.
    //
    // Tek gözlemli üründe çizilmemesi de kasıtlı: iki nokta olmadan eğim
    // yok. Tek noktadan çizilen düz çizgi "fiyat sabit kaldı" der, oysa
    // söylenebilecek tek şey "henüz ikinci kez görmedik".
    testWidgets('kıvılcım yalnızca iki gözlemden sonra çiziliyor', (
      tester,
    ) async {
      await tester.pumpWidget(
        bootstrap(
          token: 'test-token',
          api: FakeApi(
            routes: {
              ...FakeApi.defaultRoutes,
              'GET /products': [
                {
                  'id': 'p1',
                  'name': 'Ayçiçek yağı',
                  'sizeLabel': '5 litre',
                  'observations': 14,
                  'merchantCount': 4,
                  'monthSpan': 11,
                  'changePct': 57.2,
                  'history': [
                    {
                      'date': '2025-09-12',
                      'unitPrice': 49.6,
                      'packPrice': 248.0,
                    },
                    {
                      'date': '2026-08-14',
                      'unitPrice': 77.98,
                      'packPrice': 389.9,
                    },
                  ],
                },
                {
                  'id': 'p2',
                  'name': 'Tuz',
                  'sizeLabel': '750 g',
                  'observations': 1,
                  'merchantCount': 1,
                  'monthSpan': 0,
                  'changePct': null,
                  'history': [
                    {'date': '2026-08-14', 'unitPrice': 12.0, 'packPrice': 9.0},
                  ],
                },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-2')));
      await tester.pumpAndSettle();

      expect(find.text('Ayçiçek yağı, 5 litre'), findsOneWidget);
      expect(find.text('Tuz, 750 g'), findsOneWidget);
      // İki satır var, kıvılcım tek.
      expect(find.byType(LineChart), findsOneWidget);
      // Tek gözlemli satırda yüzde yerine tire duruyor.
      expect(find.text('—'), findsOneWidget);
    });
  });

  // Endeks iki FARKLI ayda fiş istiyor ve o zamana kadar ekran "bir ay daha
  // lazım" yazıp duruyordu. Bu kart o boşluğu dolduruyor: kullanıcının
  // eline endeksten önce geçen tek somut şey.
  group('Sepet karşılaştırması', () {
    Widget appWithBasket() => AppScope(
      api: FakeApi(
        routes: {
          ...FakeApi.defaultRoutes,
          'GET /index/basket': {
            'comparable': true,
            'receiptId': 'r1',
            'merchant': 'BİM',
            'itemCount': 2,
            'paid': 340.0,
            'best': 298.0,
            'saved': 42.0,
            'items': [
              {
                'name': 'Kıyma, dana kilogram',
                'paid': 200.0,
                'unitPrice': 690.33,
                'bestName': 'Kıyma, dana kilogram',
                'bestMerchant': 'Şok',
                'bestUnitPrice': 661.78,
                'bestSeenOn': '2026-07-19',
                'bestPaid': 172.0,
                'saved': 28.0,
              },
              {
                'name': 'Banvit Tavuk göğsü kilogram',
                'paid': 140.0,
                'unitPrice': 223.1,
                'bestName': 'Şenpiliç Tavuk göğsü kilogram',
                'bestMerchant': 'A101',
                'bestUnitPrice': 210.21,
                'bestSeenOn': '2026-08-02',
                'bestPaid': 126.0,
                'saved': 14.0,
              },
            ],
          },
        },
      ),
      authStore: MemoryAuthStore('test-token'),
      reminder: MemoryMonthlyReminder(),
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        home: const RootGate(),
      ),
    );

    testWidgets('tasarruf ve kıyaslanan alternatif görünüyor', (tester) async {
      await tester.pumpWidget(appWithBasket());
      await tester.pumpAndSettle();

      final kart = find.text('DAHA UCUZA GÖRMÜŞTÜN');
      await tester.ensureVisible(kart);
      await tester.pumpAndSettle();

      expect(kart, findsOneWidget);
      expect(find.text('42,00'), findsOneWidget);
      // Fişin tamamı değil, kıyaslanabilen kalemler.
      expect(find.textContaining('BİM fişindeki 2 kalemi'), findsOneWidget);

      // Kullanıcı neyle kıyaslandığını görmeden sayıya inanmak zorunda
      // kalmasın: aynı üründe market + tarih, farklı üründe marka da.
      expect(find.text('Şok · 19 TEM'), findsOneWidget);
      expect(
        find.text('Şenpiliç Tavuk göğsü kilogram · A101 · 2 AĞU'),
        findsOneWidget,
      );
      expect(find.text('−28,00'), findsOneWidget);
    });

    testWidgets('kıyaslanacak veri yoksa kart hiç çıkmıyor', (tester) async {
      // "Tasarruf yok" ile "kıyaslayacak şey yok" ayrı: ikincisinde ekran
      // 0 TL yazmamalı, susmalı. Varsayılan sahte yol comparable:false.
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.text('DAHA UCUZA GÖRMÜŞTÜN'), findsNothing);
    });
  });

  // Eşleşmeyen satır sessizce kapsam dışında kalıyordu: endeks doğru ama
  // eksik bir sepetten hesaplanıyordu ve bunu söyleyen hiçbir şey yoktu.
  group('Kapsam uyarısı', () {
    testWidgets('endekse girmeyen kalem sayısı yazıyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      // Sahte fiş listesinde bekleyen kalemler var.
      expect(find.textContaining('kalem endekse girmiyor'), findsOneWidget);
    });

    testWidgets('dokununca bekleyen fişe gidiyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('kalem endekse girmiyor'));
      await tester.pumpAndSettle();

      // Uyarı bir sayı değil, bir kapı: çözülecek fişi açıyor.
      expect(find.text('SIRAYLA ÇÖZ'), findsOneWidget);
    });
  });

  group('Kırılım', () {
    /// Endeks ekranından kırılıma gider.
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();
      // Kapsam uyarısı eklendikten sonra şerit ekranın altına düştü.
      await tester.ensureVisible(find.text('Kırılım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kırılım'));
      await tester.pumpAndSettle();
    }

    testWidgets('kategoriler en çok artandan sıralı', (tester) async {
      await open(tester);

      expect(find.text('EN ÇOK ARTAN KATEGORİ'), findsOneWidget);
      // Manşette ve listede birer kez.
      expect(find.text('Et'), findsNWidgets(2));
      expect(find.text('+39,2%'), findsNWidgets(2));
      expect(find.text('+12,5%'), findsOneWidget);
    });

    testWidgets('marka sekmesi ayrı seri getiriyor', (tester) async {
      await open(tester);
      await tester.tap(find.text('Marka'));
      await tester.pumpAndSettle();

      expect(find.text('EN ÇOK ARTAN MARKA'), findsOneWidget);
      expect(find.text('Sütaş'), findsNWidgets(2));
      // Kategori listesi gitmiş olmalı — eksen değişince veri baştan yükleniyor.
      expect(find.text('Meyve'), findsNothing);
    });

    testWidgets('yüzdeler toplanabilir sanılmasın diye not var', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('birbirine eklenmez'), findsOneWidget);
    });

    testWidgets('detayda aylar doğru etiketleniyor', (tester) async {
      await open(tester);
      await tester.tap(find.text('Meyve'));
      await tester.pumpAndSettle();

      expect(find.text('KATEGORİ · 01.1.6'), findsOneWidget);
      expect(find.text('AY AY SEVİYE'), findsOneWidget);
      // En yeni ay üstte. Saat dilimi kayması olsaydı burası "Temmuz" derdi.
      expect(find.text('Ağustos'), findsOneWidget);
      expect(find.text('112,5'), findsOneWidget);
    });

    testWidgets('kapsama düşükse uyarı çıkıyor', (tester) async {
      await open(tester);
      await tester.tap(find.text('Meyve'));
      await tester.pumpAndSettle();

      // Meyve son ayda %42 kapsıyor — eşik %25, uyarı çıkmamalı.
      expect(find.textContaining('küçük bir bölümünü'), findsNothing);
      expect(find.textContaining('zincirlenmiş endekstir'), findsOneWidget);
    });
  });

  group('Profil', () {
    // Bu düğme sunucuya hiç istek atmıyordu: yalnızca oturumu kapatıyor,
    // ekranda ise "kalıcı olarak silinir" yazıyordu. Veri sunucuda duruyordu.
    testWidgets('fişleri silme onay ister ve sunucuya gider', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(
        AppScope(
          api: api,
          authStore: MemoryAuthStore('test-token'),
          reminder: MemoryMonthlyReminder(),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-3')));
      await tester.pumpAndSettle();

      // Konuma değil anahtara bakıyoruz: profile satır eklendikçe metin
      // kaydırmanın altına düşüyor ve dokunuş sessizce ıskalıyordu.
      //
      // scrollUntilVisible yetmiyor: SliverList.list bütün çocukları kuruyor,
      // yani satır ağaçta ama ekran dışında. Görünür olması da yetmiyor —
      // yüzen sekme çubuğu alt şeridi kapatıyor, dokunuş ıskalıyor. Listeyi
      // sonuna kadar kaydırıyoruz; ScreenFrame altta çubuk kadar boşluk
      // ayırdığı için satır o zaman açıkta kalıyor.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear-receipts')));
      await tester.pumpAndSettle();

      // Onay penceresi çıkmalı; vazgeçince hiçbir şey olmamalı.
      expect(find.textContaining('endeks geçmişin silinir'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DELETE /receipts')));

      await tester.tap(find.byKey(const Key('clear-receipts')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('DELETE /receipts'));
    });
  });

  group('Market ekleme', () {
    // Listede olmayan market fişi kaydetmenin önünde katı bir duvardı:
    // "Onur Market"ten alınan fiş hiçbir şekilde girilemiyordu.
    ParsedReceipt taslak() => const ParsedReceipt(
      lines: [ParsedLine(raw: 'DURU LIMON KOLO', quantity: 1, amount: 145)],
      merchantName: 'ONUR LULEBURGAZ TASKIN',
      total: 145,
    );

    Widget ekran(FakeApi api) => AppScope(
      api: api,
      authStore: MemoryAuthStore('test-token'),
      reminder: MemoryMonthlyReminder(),
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        home: DraftReceiptScreen(parsed: taslak()),
      ),
    );

    testWidgets('fişten okunan ad ekleme alanına ön dolgu geliyor', (
      tester,
    ) async {
      final api = FakeApi();
      await tester.pumpWidget(ekran(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();

      expect(find.text('"ONUR LULEBURGAZ TASKIN" olarak ekle'), findsOneWidget);
    });

    testWidgets('yeni market sunucuya gidiyor ve seçili kalıyor', (
      tester,
    ) async {
      final api = FakeApi();
      await tester.pumpWidget(ekran(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Onur Market');
      await tester.pumpAndSettle();
      await tester.tap(find.text('"Onur Market" olarak ekle'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('POST /merchants'));
      // Sayfa kapandı ve market seçildi: artık "Önce market seç" yazmıyor.
      expect(find.text('Onur Market'), findsOneWidget);
      expect(find.text('Sepete ekle'), findsOneWidget);
    });

    // Listedeki bir market yeniden açılmasın: aynı ad iki kayıt üretmemeli.
    testWidgets('listede olan ad için ekleme satırı çıkmıyor', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(ekran(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'A101');
      await tester.pumpAndSettle();

      expect(find.textContaining('olarak ekle'), findsNothing);
      // Biri arama kutusunda, biri listede: satır süzülmüş olarak duruyor.
      expect(find.text('A101'), findsNWidgets(2));
      expect(find.text('BİM'), findsNothing);
    });
  });
}
