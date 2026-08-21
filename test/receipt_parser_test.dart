import 'package:flutter_test/flutter_test.dart';
import 'package:sepet/data/receipt_parser.dart';

/// Gerçek market fişlerinin biçimlerinden alınmış örnekler.
const a101 = '''
A101 YENİ MAĞAZACILIK A.Ş.
KIRKLARELİ ŞUBESİ
MERSİS NO: 0123456789
TARİH: 18/08/2026   SAAT: 14:32
FİŞ NO: 0042
--------------------------------
SUT TAM YAGLI 1L
   3 X 37,71             113,12
YUMURTA 30LU             182,25
BEYAZ PEYNIR 600G        208,16
DOMATES KG
   1,240 X 48,15          59,71
--------------------------------
TOPLAM                   563,24
NAKİT                    600,00
PARA ÜSTÜ                 36,76
TEŞEKKÜR EDERİZ
''';

const migros = '''
MİGROS TİCARET A.Ş.
KADIKÖY ŞUBE
TARIH:02.03.2026 SAAT:19:07
================================
EKMEK TAM BUGDAY %1        29,21
CAYKUR RIZE 1KG %8        268,00
AYCICEK YAGI 5L *         389,90
ARA TOPLAM                687,11
TOPKDV                     41,20
TOPLAM                    687,11
KREDİ KARTI               687,11
''';

void main() {
  group('Tutar ayrıştırma', () {
    test('binlik ayracı ve ondalık virgül', () {
      expect(ReceiptParser.parseAmount('1.234,56'), 1234.56);
      expect(ReceiptParser.parseAmount('123,45'), 123.45);
      expect(ReceiptParser.parseAmount('0,99'), 0.99);
    });

    test('geçersiz biçimler reddedilir', () {
      // Ondalıksız sayı tutar değil; fiş numarası ya da adet olabilir.
      expect(ReceiptParser.parseAmount('1234'), isNull);
      expect(ReceiptParser.parseAmount('12,3'), isNull);
      expect(ReceiptParser.parseAmount('abc'), isNull);
    });
  });

  group('Türkçe sadeleştirme', () {
    test('ı, İ, ğ, ş, ö, ç karşılıklarına düşer', () {
      expect(ReceiptParser.normalize('Ayçiçek Yağı'), 'AYCICEK YAGI');
      expect(ReceiptParser.normalize('İSTANBUL'), 'ISTANBUL');
      expect(ReceiptParser.normalize('Şok'), 'SOK');
    });
  });

  group('A101 fişi', () {
    final r = ReceiptParser.parse(a101);

    test('zincir ve tarih tanınır', () {
      expect(r.merchantCode, 'A101');
      expect(r.date, DateTime(2026, 8, 18));
    });

    test('dört ürün satırı çıkar, özet satırları girmez', () {
      expect(r.lines.map((l) => l.raw), [
        'SUT TAM YAGLI 1L',
        'YUMURTA 30LU',
        'BEYAZ PEYNIR 600G',
        'DOMATES KG',
      ]);
    });

    test('bir alt satırdaki adet ve birim fiyat üst satıra bağlanır', () {
      final sut = r.lines.first;
      expect(sut.quantity, 3);
      expect(sut.unitPrice, 37.71);
      expect(sut.amount, 113.12);

      // Kilogramlı ürün: miktar ondalıklı.
      final domates = r.lines.last;
      expect(domates.quantity, 1.24);
      expect(domates.amount, 59.71);
    });

    test('TOPLAM okunur ve satırlarla tutar', () {
      expect(r.total, 563.24);
      expect(r.lineSum, closeTo(563.24, 0.01));
      expect(r.balances, isTrue);
    });
  });

  group('Migros fişi', () {
    final r = ReceiptParser.parse(migros);

    test('nokta ayraçlı tarih ve zincir tanınır', () {
      expect(r.merchantCode, 'MIGROS');
      expect(r.date, DateTime(2026, 3, 2));
    });

    test('KDV oranı ve yıldız ürün adından temizlenir', () {
      expect(r.lines.map((l) => l.raw), [
        'EKMEK TAM BUGDAY',
        'CAYKUR RIZE 1KG',
        'AYCICEK YAGI 5L',
      ]);
    });

    test('ARA TOPLAM ve TOPKDV ürün sayılmaz', () {
      expect(r.lines, hasLength(3));
      expect(r.total, 687.11);
    });
  });

  group('OCR görsel ikizleri', () {
    test('Kiril çarpı işareti Latin x sayılır', () {
      // Vision fişteki "x"i Kiril "х" (U+0445) olarak okuyabiliyor; ekranda
      // aynı görünüyor ama farklı kod noktası. Sahada bu yüzden miktar
      // satırları ürün adının yerine geçmişti.
      const cyrillic =
          'A101\n'
          'SUT TAM YAGLI 1L\n'
          '   3 \u0445 38,90              116,70\n'
          'DOMATES KG\n'
          '   1,240 \u0425 74,90           92,88\n';
      final r = ReceiptParser.parse(cyrillic);

      expect(r.lines.map((l) => l.raw), ['SUT TAM YAGLI 1L', 'DOMATES KG']);
      expect(r.lines.first.quantity, 3);
      expect(r.lines.first.amount, 116.70);
      expect(r.lines.last.quantity, 1.24);
    });

    test('Kiril harfler ürün adında Latin karşılığına düşer', () {
      // "ЕKMEK" -> "EKMEK" (baştaki E Kiril)
      expect(ReceiptParser.fixHomoglyphs('\u0415KMEK'), 'EKMEK');
      expect(ReceiptParser.fixHomoglyphs('A.\u0218'), 'A.Ş');
    });
  });

  group('Bozuk girdiler', () {
    test('boş metin hata değil', () {
      final r = ReceiptParser.parse('');
      expect(r.lines, isEmpty);
      expect(r.merchantCode, isNull);
      // Toplam yoksa denge iddiası da yok.
      expect(r.balances, isTrue);
    });

    test('tanınmayan market null döner, satırlar yine çıkar', () {
      final r = ReceiptParser.parse('BAKKAL AMCA\nEKMEK          15,00\n');
      expect(r.merchantCode, isNull);
      expect(r.lines.single.raw, 'EKMEK');
      expect(r.lines.single.amount, 15);
    });

    test('gelecek tarihli fiş kabul edilmez', () {
      final future = DateTime.now().add(const Duration(days: 400));
      final text =
          'BIM BIRLESIK MAGAZALAR\n'
          'TARIH: 01/01/${future.year}\n'
          'EKMEK  15,00\n';
      expect(ReceiptParser.parse(text).date, isNull);
    });

    test('satır toplamı fişteki toplamı tutmuyorsa fark edilir', () {
      // OCR bir satırı kaçırmış: 100 + 50 = 150, fişte 300 yazıyor.
      final r = ReceiptParser.parse(
        'A101\nEKMEK 100,00\nSUT 50,00\nTOPLAM 300,00\n',
      );
      expect(r.balances, isFalse);
    });
  });
}
