import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/theme/tokens.dart';
import 'package:sepet/widgets/chart.dart';
import 'package:sepet/widgets/motion.dart';

void main() {
  Widget wrap(Widget child, {bool reduceMotion = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  /// Gecikme sayacını ateşleyen ilk kare.
  ///
  /// Sayaç kurulduğu karede değil, sonraki karede çalışıyor; sıfır süreli
  /// bekleyiş bile bir kare istiyor. Bu adım atlanırsa sayaç ile animasyonun
  /// başlangıcı aynı kareye düşüyor ve değer hiç ilerlemiyor.
  Future<void> ilkKare(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1));

  /// Ağaçtaki ilk [Opacity]'nin değeri — Printed'ın belirme durumu.
  double opacityOf(WidgetTester tester) =>
      tester.widget<Opacity>(find.byType(Opacity).first).opacity;

  group('Printed', () {
    testWidgets('önce saydam, sonra tam görünür', (tester) async {
      await tester.pumpWidget(
        wrap(const Printed(step: 0, child: Text('cevap'))),
      );

      expect(opacityOf(tester), lessThan(1));

      await ilkKare(tester);
      await tester.pump(M.enter);
      expect(opacityOf(tester), 1);
    });

    testWidgets('sıradaki blok daha geç başlıyor', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              Printed(step: 0, child: Text('önce')),
              Printed(step: 4, child: Text('sonra')),
            ],
          ),
        ),
      );

      // İlk blok yolun yarısındayken dördüncüsü henüz hiç başlamamış olmalı.
      await ilkKare(tester);
      await tester.pump(M.enter ~/ 2);
      final ilk = tester.widget<Opacity>(find.byType(Opacity).first).opacity;
      final dorduncu = tester
          .widget<Opacity>(find.byType(Opacity).last)
          .opacity;
      expect(ilk, greaterThan(dorduncu));

      // Sonunda ikisi de yerinde — hiçbir blok yolda kalmıyor.
      await tester.pump(M.enter + M.stagger * 4);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 1);
    });

    testWidgets('Hareketi Azalt açıkken ilk kareden itibaren yerinde', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const Printed(step: 6, child: Text('cevap')), reduceMotion: true),
      );

      // Ne saydamlık ne kaydırma sarmalayıcısı kuruluyor: içerik olduğu gibi.
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(Transform), findsNothing);
      expect(find.text('cevap'), findsOneWidget);
    });
  });

  group('DrawnLineChart', () {
    const seri = [
      ChartSeries(values: [100.0, 104.0, 111.0], color: C.ink),
    ];

    testWidgets('çizim ilerliyor ve tamamlanıyor', (tester) async {
      await tester.pumpWidget(wrap(const DrawnLineChart(series: seri)));

      double progress() =>
          tester.widget<LineChart>(find.byType(LineChart)).progress;

      expect(progress(), 0);
      await ilkKare(tester);
      await tester.pump(M.draw ~/ 2);
      expect(progress(), greaterThan(0));
      expect(progress(), lessThan(1));

      await tester.pump(M.draw);
      expect(progress(), 1);
    });

    testWidgets('Hareketi Azalt açıkken çizgi ilk karede tam', (tester) async {
      await tester.pumpWidget(
        wrap(const DrawnLineChart(series: seri), reduceMotion: true),
      );
      expect(tester.widget<LineChart>(find.byType(LineChart)).progress, 1);
    });
  });
}
