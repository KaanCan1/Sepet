import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/text_fold.dart';

// Arama kutusunda karşılaştırma bu katlamadan geçiyor. Her testin yanında
// düz toLowerCase'in ne yaptığı da yazıyor: katlamanın gerçekten neyi
// değiştirdiği testten okunsun, iddiadan değil.
void main() {
  group('searchFold', () {
    // Dart 'I' -> 'i' veriyor, oysa Türkçe'de 'ı' olmalı.
    test("'I' harfi Türkçe küçülüyor", () {
      expect(searchFold('IŞIK'), searchFold('ışık'));
      // Düz toLowerCase bunu yapamıyor — testin var olma sebebi bu.
      expect('IŞIK'.toLowerCase() == 'ışık'.toLowerCase(), isFalse);
    });

    // 'İ' için Dart zaten doğru davranıyor; burası bir gerileme testi.
    test("'İ' zaten sorunsuzdu, öyle kalıyor", () {
      expect(searchFold('İstanbul'), 'istanbul');
      expect(searchFold('ISTANBUL'), 'istanbul');
      expect('İstanbul'.toLowerCase() == 'ISTANBUL'.toLowerCase(), isTrue);
    });

    // Katlamanın ASIL işi bu: kimse arama kutusuna "yoğurt" yazmak için
    // klavyesini değiştirmiyor.
    test('şapka ve noktalar aranırken fark etmiyor', () {
      expect(searchFold('Süt, tam yağlı'), 'sut, tam yagli');
      expect(searchFold('Çaykur'), 'caykur');
      expect(searchFold('YOĞURT'), 'yogurt');
      expect(searchFold('Kâğıt havlu'), 'kagit havlu');
      // Hiçbiri düz toLowerCase ile eşleşmiyordu.
      for (final (a, b) in [
        ('Yoğurt', 'yogurt'),
        ('Süt', 'sut'),
        ('Çay', 'cay'),
        ('Kâğıt', 'kagit'),
      ]) {
        expect(searchFold(a), searchFold(b), reason: '$a ~ $b');
        expect(a.toLowerCase() == b.toLowerCase(), isFalse, reason: '$a ~ $b');
      }
    });

    test('katlanmış metin kendi kendine eşit kalıyor', () {
      expect(searchFold(searchFold('Şeker, toz')), searchFold('Şeker, toz'));
    });
  });
}
