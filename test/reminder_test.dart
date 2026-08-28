import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/app_scope.dart';
import 'package:sepet/data/auth_store.dart';
import 'package:sepet/data/notifications.dart';
import 'package:sepet/screens/root_gate.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'fake_api.dart';

void main() {
  group("Ayın 3'ü hesabı", () {
    setUpAll(() {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    });

    tz.TZDateTime at(int y, int m, int d, [int h = 0, int min = 0]) =>
        tz.TZDateTime(tz.local, y, m, d, h, min);

    test('ayın başındaysak bu ayın 3ü', () {
      expect(
        LocalMonthlyReminder.nextOccurrence(at(2026, 8, 1)),
        at(2026, 8, 3, 10, 30),
      );
    });

    test('3ü ama saat henüz gelmediyse yine bugün', () {
      expect(
        LocalMonthlyReminder.nextOccurrence(at(2026, 8, 3, 9, 0)),
        at(2026, 8, 3, 10, 30),
      );
    });

    test('saat geçtiyse gelecek ay — aynı gün iki kez planlanmıyor', () {
      expect(
        LocalMonthlyReminder.nextOccurrence(at(2026, 8, 3, 10, 30)),
        at(2026, 9, 3, 10, 30),
      );
      expect(
        LocalMonthlyReminder.nextOccurrence(at(2026, 8, 3, 11, 0)),
        at(2026, 9, 3, 10, 30),
      );
    });

    test('aralıktan ocağa yıl atlıyor', () {
      expect(
        LocalMonthlyReminder.nextOccurrence(at(2026, 12, 20)),
        at(2027, 1, 3, 10, 30),
      );
    });

    test('şubatın 3ü kısa ayda da yerinde', () {
      expect(
        LocalMonthlyReminder.nextOccurrence(at(2026, 1, 31)),
        at(2026, 2, 3, 10, 30),
      );
    });
  });

  group('Profil anahtarı', () {
    Future<void> pumpProfile(WidgetTester tester, MonthlyReminder r) async {
      await tester.pumpWidget(
        AppScope(
          api: FakeApi(),
          authStore: MemoryAuthStore('test-token'),
          reminder: r,
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            home: const RootGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Profil sekmesi.
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
    }

    Switch reminderSwitch(WidgetTester tester) =>
        tester.widget<Switch>(find.byKey(const Key('monthly-reminder')));

    testWidgets('varsayılan kapalı — izin istenmeden açık gösterilmiyor', (
      tester,
    ) async {
      await pumpProfile(tester, MemoryMonthlyReminder());
      expect(reminderSwitch(tester).value, isFalse);
    });

    testWidgets('tercih açıksa anahtar açık geliyor', (tester) async {
      await pumpProfile(tester, MemoryMonthlyReminder(on: true));
      expect(reminderSwitch(tester).value, isTrue);
    });

    testWidgets('açınca planlanıyor, kapatınca iptal ediliyor', (tester) async {
      final r = MemoryMonthlyReminder();
      await pumpProfile(tester, r);

      await tester.tap(find.byKey(const Key('monthly-reminder')));
      await tester.pumpAndSettle();
      expect(await r.isOn(), isTrue);
      expect(reminderSwitch(tester).value, isTrue);

      await tester.tap(find.byKey(const Key('monthly-reminder')));
      await tester.pumpAndSettle();
      expect(await r.isOn(), isFalse);
      expect(reminderSwitch(tester).value, isFalse);
    });

    testWidgets(
      'izin reddedilirse anahtar açık kalmıyor, ne yapılacağı yazıyor',
      (tester) async {
        final r = MemoryMonthlyReminder(permission: false);
        await pumpProfile(tester, r);

        await tester.tap(find.byKey(const Key('monthly-reminder')));
        await tester.pumpAndSettle();

        expect(reminderSwitch(tester).value, isFalse);
        expect(await r.isOn(), isFalse);
        expect(find.textContaining('Ayarlar'), findsOneWidget);
      },
    );
  });
}
