/**
 * Eşleştirme ölçüm kümesi — ham fiş metni ve doğru kanonik ürün.
 *
 * Eşik değerleri şimdiye kadar iki gerçek fiş üzerinde göz kararı
 * ayarlanmıştı ("doğru aday 0,90'ın üstünde toplanıyor") ve bu genellemedi:
 * ölçünce doğru cevapların büyük kısmı 0,66–0,70 aralığında çıktı ve
 * eşiğin altında kaldığı için kullanıcıya soruluyordu.
 *
 * Kalibrasyon tahminle yapılamaz — bu küme onun için var. Etiketler gerçek
 * fiş satırlarından geliyor ve ürünü UUID ile değil ÜÇLÜ KİMLİKLE
 * (grup + marka + boy) tutuyor: katalog kimlikleri her veritabanında
 * yeniden üretiliyor, üçlü kimlik ise kataloğun kendi sözleşmesi.
 *
 * Bir satırın "soruldu" çıkması her zaman hata değil: fişte boy yazmıyorsa
 * sormak DOĞRU davranış. Ölçüm bu yüzden tek sayı vermiyor — yanlış
 * otomatik eşleşme ile gereksiz soruyu ayrı sayıyor.
 */
export type MatchCase = {
  raw: string;
  group: string;
  /** Kasada tartılan kalemlerde (domates, açık kıyma) marka yok. */
  brand: string | null;
  size: string;
};

export const MATCH_CASES: MatchCase[] = [
  { raw: 'ARIEL SIVI 3 LT', group: 'Deterjan, çamaşır', brand: 'Ariel', size: '3 litre' },
  { raw: 'BALKUPU TOZ SEKER 1KG', group: 'Şeker, toz', brand: 'Balküpü', size: '1 kg' },
  { raw: 'BANVIT TAVUK GOGUS KG', group: 'Tavuk göğsü', brand: 'Banvit', size: 'kilogram' },
  { raw: 'CAYKUR RIZE TURIST 1KG', group: 'Çay, siyah', brand: 'Çaykur', size: '1 kg' },
  { raw: 'COCA COLA 2.5 LT', group: 'Gazlı içecek, kola', brand: 'Coca-Cola', size: '2,5 litre' },
  { raw: 'DANA KIYMA KG', group: 'Kıyma, dana', brand: null, size: 'kilogram' },
  { raw: 'DOGUS KARADENIZ CAY 1000 GR', group: 'Çay, siyah', brand: 'Doğuş', size: '1 kg' },
  { raw: 'DOMATES KG', group: 'Domates', brand: null, size: 'kilogram' },
  { raw: 'DURU PILAVLIK BULGUR 1KG', group: 'Bulgur, pilavlık', brand: 'Duru', size: '1 kg' },
  { raw: 'ELIDOR SAMPUAN 500ML', group: 'Şampuan', brand: 'Elidor', size: '500 mL' },
  { raw: 'ELMA STARKING KG', group: 'Elma', brand: null, size: 'kilogram' },
  { raw: 'ERIKLI SU 5L', group: 'Su, doğal kaynak', brand: 'Erikli', size: '5 litre' },
  { raw: 'FAIRY BULASIK 1300ML', group: 'Bulaşık deterjanı', brand: 'Fairy', size: '1,3 litre' },
  { raw: 'FILIZ BURGU MAKARNA 500G', group: 'Makarna, burgu', brand: 'Filiz', size: '500 g' },
  { raw: 'KOMILI RIVIERA 1L', group: 'Zeytinyağı', brand: 'Komili', size: '1 litre' },
  { raw: 'KURU SOGAN KG', group: 'Soğan, kuru', brand: null, size: 'kilogram' },
  { raw: 'MEHMET EFENDI TURK KAHVESI 250G', group: 'Türk kahvesi', brand: 'Kurukahveci Mehmet Efendi', size: '250 g' },
  { raw: 'MUZ ITHAL KG', group: 'Muz', brand: null, size: 'kilogram' },
  { raw: 'NUHUN ANKARA MAKARNA 500 G', group: 'Makarna, burgu', brand: 'Nuhun Ankara', size: '500 g' },
  { raw: 'OMO SIVI DETERJAN 3L', group: 'Deterjan, çamaşır', brand: 'Omo', size: '3 litre' },
  { raw: 'ORKIDE AYCICEK 5 LT', group: 'Ayçiçek yağı', brand: 'Orkide', size: '5 litre' },
  { raw: 'PATATES KG', group: 'Patates', brand: null, size: 'kilogram' },
  { raw: 'PINAR YOGURT 1.5 KG', group: 'Yoğurt', brand: 'Pınar', size: '1,5 kg' },
  { raw: 'SALATALIK KG', group: 'Salatalık', brand: null, size: 'kilogram' },
  { raw: 'SARELLE FINDIK KREMASI 350 G', group: 'Fındık kreması', brand: 'Sarelle', size: '350 g' },
  { raw: 'SELPAK KAGIT HAVLU 8LI', group: 'Kağıt havlu', brand: 'Selpak', size: '8\'li' },
  { raw: 'SELPAK TUVALET KAGIDI 16LI', group: 'Tuvalet kağıdı', brand: 'Selpak', size: '16\'lı' },
  { raw: 'SENPILIC TAVUK GOGUS', group: 'Tavuk göğsü', brand: 'Şenpiliç', size: 'kilogram' },
  { raw: 'SINANGIL UN 2KG', group: 'Un, buğday', brand: 'Sinangil', size: '2 kg' },
  { raw: 'SIVRI BIBER KG', group: 'Biber, sivri', brand: null, size: 'kilogram' },
  { raw: 'SUTAS AYRAN 1L', group: 'Ayran', brand: 'Sütaş', size: '1 litre' },
  { raw: 'SUTAS BEYAZ PEYNIR 600G', group: 'Beyaz peynir', brand: 'Sütaş', size: '600 g' },
  { raw: 'SUTAS TAM YAGLI SUT 1L', group: 'Süt, tam yağlı', brand: 'Sütaş', size: '1 litre' },
  { raw: 'SUTAS TEREYAG 250 GR', group: 'Tereyağı', brand: 'Sütaş', size: '250 g' },
  { raw: 'SUTAS YOGURT 1.5KG', group: 'Yoğurt', brand: 'Sütaş', size: '1,5 kg' },
  { raw: 'TAHSILDAROGLU EZINE 600 G', group: 'Beyaz peynir', brand: 'Tahsildaroğlu', size: '600 g' },
  { raw: 'TAM BUGDAY EKMEK', group: 'Ekmek, tam buğday', brand: null, size: '500 g' },
  { raw: 'TAT DOMATES SALCASI 700G', group: 'Salça, domates', brand: 'Tat', size: '700 g' },
  { raw: 'YAYLA KIRMIZI MERCIMEK 1 KG', group: 'Mercimek, kırmızı', brand: 'Yayla', size: '1 kg' },
  { raw: 'YUMURTA 30LU', group: 'Yumurta', brand: null, size: '30\'lu' },
];

/**
 * OLUMSUZ vakalar: doğru cevabı katalogda OLMAYAN satırlar.
 *
 * Bunlar olmadan kalibrasyon anlamsız. Yukarıdaki kümenin her satırının
 * karşılığı katalogda var; öyle bir kümede eşiği düşürmek ancak iyi
 * görünür ve ölçüm "hep evet de" diyen bir eşleştiriciyi kusursuz sanır.
 *
 * Oysa gerçek fişte katalogda olmayan onlarca kalem var ve orada yanlış
 * bağlamak, sormaktan çok daha pahalı: endeks birim fiyattan hesaplandığı
 * için sessizce yanlış enflasyon üretiyor.
 *
 * Vakalar kasıtlı olarak DÜŞMANCA — her biri katalogdaki bir marka ya da
 * grupla çakışıyor:
 *
 *   LAYS PATATES CIPSI   "Patates" grubu var, cips yok
 *   IPEK TUZ             "Şeker, toz" — TUZ ile TOZ bir harf farkla
 *   ORKID PED            "Orkide" markası var (ayçiçek yağı)
 *   NESCAFE GOLD         Nescafe markası ve "Kahve, filtre" grubu var
 *   COLGATE DIS FIRCASI  Colgate markası ve "Diş macunu" grubu var
 *   BEBEK BEZI 30LU      "Yumurta 30'lu" ile aynı adet eki
 *
 * Beklenen davranış hepsinde aynı: otomatik BAĞLAMA. Kullanıcıya sormak
 * doğru cevap.
 */
export const NEGATIVE_CASES: string[] = [
  'LAYS PATATES CIPSI 150G',
  'IPEK TUZ 750G',
  'ORKID PED 16LI',
  'NESCAFE GOLD 100G',
  'COLGATE DIS FIRCASI ORTA',
  'BEBEK BEZI 4 NUMARA 30LU',
  'ULKER CIKOLATA 80G',
  'ETI BISKUVI 100G',
  'PINAR SUCUK 400G',
  'TORKU HELVA 350G',
  'ULUDAG GAZOZ 1L',
  'SELPAK PECETE 100LU',
  'BIZIM MARGARIN 250G',
  'DOMESTOS YUZEY TEMIZLEYICI 750ML',
  'MARLBORO TOUCH',
  'KINIK SIYAH ZEYTIN 400G',
  'DALIN BEBEK SAMPUANI 500ML',
  'SEK KAYMAK 200G',
];
