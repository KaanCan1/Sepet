import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/fmt.dart';
import 'package:flutter/cupertino.dart';
import 'package:sepet/data/session.dart';
import 'package:sepet/main.dart';
import 'package:sepet/widgets/atoms.dart';

void main() {
  group('Fmt', () {
    test('binlik ayracı nokta, ondalık virgül', () {
      expect(Fmt.money(1917.45), '1.917,45');
      expect(Fmt.money(842.6), '842,60');
      expect(Fmt.money(496.2), '496,20');
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

  testWidgets('01 Endeks açılır, 04 Aylık kart\'a geçilir', (tester) async {
    await tester.pumpWidget(const SepetApp());
    await tester.pumpAndSettle();

    expect(find.text('Sepetin'), findsOneWidget);
    expect(find.text('Senin sepetin'), findsOneWidget);
    expect(find.text('TÜİK TÜFE'), findsOneWidget);
    expect(find.text('47,2%'), findsOneWidget);

    await tester.tap(find.text('Ağustos özeti'));
    await tester.pumpAndSettle();

    expect(find.text('BENİM SEPETİM'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);
  });

  testWidgets('02 Fiş okuma: eşleşme onaylanmadan sepete eklenemez', (
    tester,
  ) async {
    await tester.pumpWidget(const SepetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scan-button')));
    // Tarama çizgisi dönerken pumpAndSettle takılır; elle ilerlet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Fişi okut'), findsOneWidget);

    // Cihaz üstü OCR gecikmesi bitene kadar bekle.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // İki satır eşleşme onayı bekliyor: düğme kilitli.
    expect(find.text('Önce 2 eşleşmeyi onayla'), findsOneWidget);
    expect(find.byType(MatchFlag), findsNWidgets(2));

    // İlk işaretli satırı onayla.
    await tester.tap(find.text("Yumurta, 30'lu").first);
    await tester.pumpAndSettle();
    expect(find.text('HANGİ ÜRÜN?'), findsOneWidget);
    await tester.tap(find.text("Yumurta, 15'li"));
    await tester.pumpAndSettle();

    expect(find.text('Önce 1 eşleşmeyi onayla'), findsOneWidget);
    expect(find.byType(MatchFlag), findsOneWidget);

    // İkincisini de onayla — düğme açılır.
    await tester.tap(find.text('Domates').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Domates, salkım'));
    await tester.pumpAndSettle();

    expect(find.text('Sepete ekle'), findsOneWidget);
  });

  testWidgets('03 Ürün geçmişi ürün listesinden açılır', (tester) async {
    await tester.pumpWidget(const SepetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Sepetindeki ürünler'), findsOneWidget);

    await tester.tap(find.text('Ayçiçek yağı, 5 litre'));
    await tester.pumpAndSettle();

    expect(find.text('SEPETİNDEKİ ÜRÜN'), findsOneWidget);
    expect(find.text('İLK GÖRDÜĞÜN'), findsOneWidget);
    expect(find.text('+57%'), findsOneWidget);
  });

  testWidgets('Giriş → açık rıza: aydınlatmadan ayrı, varsayılan kapalı', (
    tester,
  ) async {
    session.value = null;
    await tester.pumpWidget(const SepetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Giriş yap'), findsOneWidget);

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    // Geçersiz e-posta: düğme kilitli, uyarı görünür.
    await tester.enterText(find.byType(CupertinoTextField), 'kaansepet');
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(session.value, isNull);

    // Geçerli e-posta: oturum açılır ve rıza ekranı gelir.
    await tester.enterText(find.byType(CupertinoTextField), 'kaan@sepet.app');
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir e-posta adresi gir.'), findsNothing);
    await tester.tap(find.text('Devam et'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(session.value?.email, 'kaan@sepet.app');

    // Açık rıza ayrı ekranda ve iki izin de kapalı geliyor.
    expect(find.text('İsteğe bağlı\nizinler'), findsOneWidget);
    expect(session.value?.consentAggregate, isFalse);
    expect(session.value?.consentMarketing, isFalse);

    // Aydınlatma metni ayrı ekran — onay kutusu içermiyor.
    await tester.tap(find.text('Aydınlatma metni'));
    await tester.pumpAndSettle();
    expect(find.text('İŞLEME AMACI VE HUKUKİ SEBEBİ'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CupertinoSwitch), findsNothing);
  });

  testWidgets('Rıza açılıp kapatılabilir', (tester) async {
    session.value = Session(
      email: 'kaan@sepet.app',
      since: DateTime(2025, 9, 1),
      receipts: 38,
      observations: 214,
    );
    await tester.pumpWidget(const SepetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-3')));
    await tester.pumpAndSettle();

    // Profil uzun bir liste — satır görünür alana girmeden dokunulamaz.
    await tester.ensureVisible(find.text('İzinler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İzinler'));
    await tester.pumpAndSettle();

    expect(find.text('Anonim endekse katkı'), findsOneWidget);
    expect(session.value?.consentAggregate, isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(session.value?.consentAggregate, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(session.value?.consentAggregate, isFalse);

    session.value = null;
  });
}
