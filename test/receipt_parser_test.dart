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

/// Apple Vision'ın gerçek çıktısı — 24.08.2026 tarihli BİM e-arşiv faturası,
/// OcrPlugin.assemble() ile aynı satır kurma mantığından geçirilmiş hâli.
///
/// Bu fiş hiç okunamıyordu: tutarlar ondalık NOKTA ile ve başlarında yıldızla
/// basılıyor, miktar satırı ürün adından önce geliyor, tutar da adın altındaki
/// ayrı satırda. Üçü birden eski ayrıştırıcının varsayımlarını kırıyordu.
const bimEArsivOcr = """
MI
E-Arsiv Fatura
BIM BIRLESIK MAGAZALAR A.
S
Yıldız Mah. Istanbul Cad.N
o:108
Lüleburgaz/Kırklareli
Büyük Mükeliefler VDM 17500
51846
FATURA NO:T082026153853216
24.08.2026 17:45  Sir
a No: 95
ETTN91845199-45ff-4b77-aa60-16c
0a546f343
52080012408612440095
TCKN/VKN:11111111111-NIHAI TÜKE
TICI
0.983 kg X 199.00
PILIÇ BONFİLE  %1
*195.62
4 ad X 59.00
PROTEIN BAR 50 G  %1.
*236.00
TOPLAM KDV
15
Odenecek  KDV Dahil Tutar
*431.62
Banka Kredi Kartı (1)
*431.62
IS BANKASI
I: 664030285 T:S0I08405  454360*
*****1154
- 24.08.2026 17:45 B:1661 S:47
Onay No:387068  Ref.No:623646
180342
KDV  MATRAH  KDV TUTAR
DV DAHIL
%1.  427.35  *4.27
*431.62
POS:1 - 81200 - G**** K****
5208, KURTULUŞ - L.BURGAZ/KIRKS  954452081
No: 1244
""";

/// Aynı gün Migros'tan alınmış e-arşiv bilgi fişi, yine gerçek Vision çıktısı.
///
/// Buradaki tuzak farklı: Vision kuruşu ayrı bir gözlem olarak döndürüyor,
/// birleştirici araya boşluk koyuyor ve "*289  00" ortaya çıkıyor. Ayrıca
/// KDV oranı kolonu ürün adının hemen sağında.
const migrosEArsivOcr = """
MIGROS TICARET A.S.
LULEBURGAZ KIRKLARELI MIGROS STS MGZS.
AIATURK MH. DR.FERIT_NEJAT CAD. NO:2  TEL: (0850)2846985
LULEBURGAZ/KIRKLARELI
BUYJK MUKELLEFLER V.D.6220529513
MERKEZ ADREST: ATATÜRK МAН. TURGUT ÖZAL
BULV. NO:7 ATAŞEHİR/İSTANBUL
TARIH:24/08/2026  SAAT:18:05
FIŞ NO  :0093
BİLGİ FİŞİ
TÜR:e-ARSIV FATURA
Fatura/İrsaliye Seri Sıra No:
92030020498260824
MUŞTERI TCKN:11111111111
#6002080584721771
MIGROS PLASTIK POSET  %20  *1,00
TACIROGLI TAM YAGLI  %1  *289  00
MIGROS EKSTRA CECIL  *149  ,90
** HASATA PILAVLIK B  *49  95
MIGROS T.YAGLI YOGU.  *191  95
UNTAD PREMIUM  TAMBU  x129  00
VIVA HAVLU GLI  %20  *89  95
ARA TOPLAM  *900.75
TOPKDV  *23,18
TOPLAM  *900,75
#454360******1154  ORTAK POS  *900.75
KASİYER  011  324856
FATURA:https://earsiv.migros.com.tr/
XXX*XXХX*XXХ*XXxx*x*Xxxxx*xxxxxxxxxxxxxx
MONEY İLE BU FİŞİNİZDE  24,00TL
İNDİRIMLİ ALIŞVERİŞ YAPTINIZ
X*X**xxxxxxxx*xxxxxxxx***xxx*x*XxxXXXX
0493 9203/002/011 + 24/08/26 18:04 AC-04
92030020498260824
SATIS
454360******1154
*900,75 TL
REF NO : 623646436627
ONAY KODU : 636008
Isyeri ID:0696497205 Sira No:000022  IS 3ANKASI
Terninal ID:S1B34S04 Batch No:000286
MERSIS NO: 0622052951300016
http://www.migros.com.tr
ÜRSALIYE  YERİNE GECER
IMZA:
Z NO:3020
""";

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

  group('BİM e-arşiv faturası (gerçek Vision çıktısı)', () {
    final fis = ReceiptParser.parse(bimEArsivOcr);

    test('zincir ve tarih tanınır', () {
      expect(fis.merchantCode, 'BIM');
      expect(fis.date, DateTime(2026, 8, 24));
    });

    test('iki ürünün ikisi de okunur', () {
      expect(fis.lines.map((l) => l.raw), [
        'PILIÇ BONFİLE',
        'PROTEIN BAR 50 G',
      ]);
    });

    test('tutarlar ondalık noktayla ve yıldız önekiyle çözülür', () {
      expect(fis.lines[0].amount, closeTo(195.62, 0.001));
      expect(fis.lines[1].amount, closeTo(236.00, 0.001));
    });

    test('ürün adından önce gelen miktar satırı doğru ürüne bağlanır', () {
      expect(fis.lines[0].quantity, closeTo(0.983, 0.0001));
      expect(fis.lines[0].unitPrice, closeTo(199.00, 0.001));
      expect(fis.lines[1].quantity, 4);
      expect(fis.lines[1].unitPrice, closeTo(59.00, 0.001));
    });

    test('toplam, KDV toplamı değil ödenecek tutardır', () {
      // "TOPLAM KDV *4.27" ile "Ödenecek KDV Dahil Tutar *431.62" ayrı şeyler.
      expect(fis.total, closeTo(431.62, 0.001));
      expect(fis.balances, isTrue);
    });
  });

  group('Migros e-arşiv bilgi fişi (gerçek Vision çıktısı)', () {
    final fis = ReceiptParser.parse(migrosEArsivOcr);

    test('zincir ve tarih tanınır', () {
      expect(fis.merchantCode, 'MIGROS');
      expect(fis.date, DateTime(2026, 8, 24));
    });

    test('yedi kalemin hepsi okunur', () {
      expect(fis.lines, hasLength(7));
    });

    test('KDV oranı kolonu ürün adına yapışmaz', () {
      expect(fis.lines.first.raw, 'MIGROS PLASTIK POSET');
      expect(fis.lines.map((l) => l.raw).any((n) => n.contains('%')), isFalse);
    });

    test('kampanya yıldızı ürün adının başından atılır', () {
      expect(fis.lines.map((l) => l.raw), contains('HASATA PILAVLIK B'));
    });

    test('boşlukla bölünmüş kuruş kısmı toparlanır', () {
      // Vision "*289  00" döndürüyor; 289,00 olarak okunmalı.
      final tacir = fis.lines.firstWhere((l) => l.raw.startsWith('TACIROGL'));
      expect(tacir.amount, closeTo(289.00, 0.001));
    });

    test('satırların toplamı fişteki toplamı tutar', () {
      expect(fis.total, closeTo(900.75, 0.001));
      expect(fis.lineSum, closeTo(900.75, 0.01));
      expect(fis.balances, isTrue);
    });
  });
}
