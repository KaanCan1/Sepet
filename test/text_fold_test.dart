import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/text_fold.dart';

// Arama kutusunda karşılaştırma bu katlamadan geçiyor. İki ayrı tuzak var
// ve ikisi de sessizce "sonuç yok" veriyordu.
void main() {
  group('searchFold', () {
    // Dart'ın toLowerCase()'i Türkçe bilmiyor: 'I' -> 'i' veriyor (oysa 'ı'
    // olmalı) ve 'İ' -> 'i' + ayrı bir birleştirici nokta veriyor.
    test('Türkçe büyük harfler doğru küçülüyor', () {
      expect(searchFold('İstanbul'), 'istanbul');
      expect(searchFold('ISTANBUL'), 'istanbul');
      // Noktalı İ'nin arkasında birleştirici nokta kalmıyor.
      expect(searchFold('İ').length, 1);
    });

    // Kimse arama kutusuna "yoğurt" yazmak için klavyesini değiştirmiyor.
    test('şapka ve noktalar aranırken fark etmiyor', () {
      expect(searchFold('Süt, tam yağlı'), 'sut, tam yagli');
      expect(searchFold('Çaykur'), 'caykur');
      expect(searchFold('YOĞURT'), 'yogurt');
      expect(searchFold('Kâğıt havlu'), 'kagit havlu');
    });

    test('katlanmış metin kendi kendine eşit kalıyor', () {
      expect(searchFold(searchFold('Şeker, toz')), searchFold('Şeker, toz'));
    });
  });
}
