import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/app_scope.dart';
import 'package:sepet/data/auth_store.dart';
import 'package:sepet/data/fmt.dart';
import 'package:sepet/data/session.dart';
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
  setUp(() => session.value = null);

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
}
