import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/app_scope.dart';
import 'package:sepet/data/auth_store.dart';
import 'package:sepet/data/fmt.dart';
import 'package:sepet/screens/root_gate.dart';
import 'package:sepet/screens/shell.dart';
import 'package:sepet/screens/welcome_screen.dart';
import 'package:sepet/widgets/atoms.dart';

import 'fake_api.dart';

/// Uygulamayı sahte sunucuyla kurar.
Widget bootstrap({String? token}) => AppScope(
  api: FakeApi(),
  authStore: MemoryAuthStore(token),
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
      expect(
        find.text('Resmî ve bağımsız ölçümler henüz çekilmedi.'),
        findsOneWidget,
      );
    });

    testWidgets('son fişler bekleyen eşleşmeyi gösteriyor', (tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 EŞLEŞME'), findsWidgets);
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
      expect(find.byType(MatchFlag), findsOneWidget);
      expect(find.textContaining('1 EŞLEŞME ONAYI BEKLİYOR'), findsOneWidget);
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
  });

  group('Kırılım', () {
    /// Endeks ekranından kırılıma gider.
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(bootstrap(token: 'test-token'));
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
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-3')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Fişleri sil'), 120);
      await tester.tap(find.text('Fişleri sil'));
      await tester.pumpAndSettle();

      // Onay penceresi çıkmalı; vazgeçince hiçbir şey olmamalı.
      expect(find.textContaining('endeks geçmişin silinir'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DELETE /receipts')));

      await tester.tap(find.text('Fişleri sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('DELETE /receipts'));
    });
  });
}
