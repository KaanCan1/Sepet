import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/fmt.dart';

void main() {
  group('Adet eki ünlü uyumuna uyuyor', () {
    // Katalogdaki mevcut etiketlerle aynı yazılmak zorunda: 30'lu, 8'li,
    // 16'lı, 6'lı. Ek sayının OKUNUŞUNDAKİ son ünlüye göre değişiyor.
    test('katalogdaki biçimleri üretiyor', () {
      expect(SizeLabel.build(30, 'adet'), "30'lu"); // otuz
      expect(SizeLabel.build(8, 'adet'), "8'li"); // sekiz
      expect(SizeLabel.build(16, 'adet'), "16'lı"); // altı
      expect(SizeLabel.build(6, 'adet'), "6'lı"); // altı
      expect(SizeLabel.build(3, 'adet'), "3'lü"); // üç
      expect(SizeLabel.build(10, 'adet'), "10'lu"); // on
      expect(SizeLabel.build(100, 'adet'), "100'lü"); // yüz
    });
  });

  group('Ağırlık ve hacim etiketleri', () {
    test('sayı ve birim ayrı yazılıyor', () {
      expect(SizeLabel.build(400, 'g'), '400 g');
      expect(SizeLabel.build(1.5, 'kg'), '1,5 kg');
      expect(SizeLabel.build(750, 'mL'), '750 mL');
    });
  });

  group('Kanonik birime çevirme', () {
    test('gram ve mililitre bine bölünüyor', () {
      // Endeks birim fiyatı buradan hesaplıyor: 400 g -> 0,4 kg.
      expect(SizeLabel.toCanonical(400, 'g'), 0.4);
      expect(SizeLabel.toCanonical(750, 'mL'), 0.75);
    });

    test('kanonik birimin kendisi olduğu gibi kalıyor', () {
      expect(SizeLabel.toCanonical(1.5, 'kg'), 1.5);
      expect(SizeLabel.toCanonical(1, 'litre'), 1);
      expect(SizeLabel.toCanonical(6, 'adet'), 6);
    });
  });

  group('Birim seçenekleri', () {
    // Liste eskiden grubun ölçü boyutuyla sınırlıydı ve bu bir çıkmaz
    // üretiyordu: fişte "TACIROGLU SUT" yazan kalem aslında kaşar peyniriyse
    // kullanıcının gireceği boy 400 g, ama ekran yalnızca mL ve litre
    // öneriyordu. Yazan şey ile satın alınan şey her zaman aynı değil.
    test('bütün birimler sunuluyor', () {
      expect(SizeLabel.unitsFor('litre'), contains('g'));
      expect(SizeLabel.unitsFor('kilogram'), contains('litre'));
      expect(SizeLabel.unitsFor('adet'), contains('kg'));
    });

    // Sıra ürünün kendi boyutunu başa alıyor: yaygın hâl tek dokunuşta
    // kalsın, boyut değiştirmek bilinçli bir seçim olsun.
    test('grubun kendi boyutu başta duruyor', () {
      expect(SizeLabel.unitsFor('kilogram').first, 'g');
      expect(SizeLabel.unitsFor('litre').first, 'mL');
      expect(SizeLabel.unitsFor('adet').first, 'adet');
    });
  });

  group('Birimin ölçü boyutu', () {
    // Gramaj ekranı bununla karar veriyor: girilen birim grubun boyutundan
    // farklıysa yanlış olan birim değil, kalemin bağlı olduğu grup.
    test('birim kanonik boyuta çözülüyor', () {
      expect(SizeLabel.dimensionOf('g'), 'kilogram');
      expect(SizeLabel.dimensionOf('kg'), 'kilogram');
      expect(SizeLabel.dimensionOf('mL'), 'litre');
      expect(SizeLabel.dimensionOf('litre'), 'litre');
      expect(SizeLabel.dimensionOf('adet'), 'adet');
    });

    test('boyutun kısa adı birim fiyat etiketinde geçen sözcük', () {
      expect(SizeLabel.shortUnit('kilogram'), 'kg');
      expect(SizeLabel.shortUnit('litre'), 'litre');
      expect(SizeLabel.shortUnit(null), 'adet');
    });
  });
}
