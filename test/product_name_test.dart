import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/product_name.dart';

void main() {
  group('Kesilmiş adlar açılır', () {
    test('Migros fişindeki kısaltmalar', () {
      // Hepsi 24.08.2026 tarihli gerçek fişten.
      expect(
        ProductName.expand('MIGROS T.YAGLI YOGU.'),
        'MIGROS tam yağlı yoğurt',
      );
      expect(
        ProductName.expand('UNTAD PREMIUM  TAMBU'),
        'UNTAD premium tam buğday',
      );
      expect(ProductName.expand('HASATA PILAVLIK B'), 'HASATA pilavlık bulgur');
      expect(
        ProductName.expand('MIGROS EKSTRA CECIL'),
        'MIGROS ekstra çeçil peyniri',
      );
      expect(
        ProductName.expand('MIGROS PLASTIK POSET'),
        'MIGROS plastik poşet',
      );
    });

    test('düşmüş Türkçe harfler geri gelir', () {
      expect(ProductName.expand('PILIÇ BONFİLE'), 'Piliç bonfile');
      expect(ProductName.expand('TAVUK GOGSU'), 'Tavuk göğsü');
      expect(ProductName.expand('KAGIT HAVLU'), 'Kağıt havlu');
    });

    test('adet eki kesme işaretiyle yazılır', () {
      expect(ProductName.expand('YUMURTA 30LU'), "Yumurta 30'lu");
      expect(ProductName.expand('SELPAK HAVLU 8LI'), "SELPAK havlu 8'lı");
    });

    test('uzun kalıp kısa olandan önce gelir', () {
      // "TAM YAGLI" bütün olarak eşleşmeli, "YAGLI" tek başına değil.
      expect(ProductName.expand('SUT TAM YAGLI 1L'), 'Süt tam yağlı 1L');
      expect(ProductName.expand('SUT Y.YAGLI'), 'Süt yarım yağlı');
    });
  });

  group('Uydurmuyor', () {
    test('tanınmayan belirteç olduğu gibi kalır', () {
      // Vision "6LI"yi "GLI" okumuş. Bu bir OCR hatası, kısaltma değil —
      // buradan 6 üretmek uydurmak olur.
      expect(ProductName.expand('VIVA HAVLU GLI'), 'VIVA havlu GLI');
      expect(ProductName.expand('ZZZTOP MARKA XQ'), 'ZZZTOP MARKA XQ');
    });

    test('boş girdi olduğu gibi döner', () {
      expect(ProductName.expand(''), '');
      expect(ProductName.expand('   '), '   ');
    });
  });
}
