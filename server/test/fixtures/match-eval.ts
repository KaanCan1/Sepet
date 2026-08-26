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

  // ── Katalog genişledi ───────────────────────────────────────────────────
  // Bunlar bir zamanlar OLUMSUZ vakaydı: karşılıkları katalogda yoktu ve
  // eşleştiricinin onlara dokunmaması doğruydu. Katalog o grupları
  // kazanınca beklenen davranış tersine döndü — ölçüm kümesi kataloğun
  // gerçeğini izlemek zorunda, yoksa doğru davranışı hata sayar.
  { raw: 'LAYS PATATES CIPSI 150G', group: 'Cips', brand: 'Lays', size: '150 g' },
  { raw: 'ORKID PED 16LI', group: 'Ped, hijyenik', brand: 'Orkid', size: '16\'lı' },
  { raw: 'ULKER CIKOLATA 80G', group: 'Çikolata', brand: 'Ülker', size: '80 g' },
  { raw: 'ETI BISKUVI 100G', group: 'Bisküvi', brand: 'Eti', size: '100 g' },
  { raw: 'PINAR SUCUK 400G', group: 'Sucuk', brand: 'Pınar', size: '400 g' },
  { raw: 'TORKU HELVA 350G', group: 'Helva', brand: 'Torku', size: '350 g' },
  { raw: 'ULUDAG GAZOZ 1L', group: 'Gazoz', brand: 'Uludağ', size: '1 litre' },
  { raw: 'SELPAK PECETE 100LU', group: 'Peçete', brand: 'Selpak', size: '100\'lü' },
  { raw: 'BIZIM MARGARIN 250G', group: 'Margarin', brand: 'Bizim', size: '250 g' },
  { raw: 'DOMESTOS YUZEY TEMIZLEYICI 750ML', group: 'Yüzey temizleyici', brand: 'Domestos', size: '750 mL' },
  { raw: 'SEK KAYMAK 200G', group: 'Kaymak', brand: 'Sek', size: '200 g' },
  { raw: 'NESCAFE GOLD 100G', group: 'Kahve, hazır', brand: 'Nescafe', size: '100 g' },
  // Yapışık yazım — A101 ve e-arşiv yazıcıları adı boşluksuz basıyor.
  // Boşluklu hâlleri zaten eşleşiyordu; ölçülen şey okumanın kendisi.
  { raw: 'PINARYOGURT1.5KG', group: 'Yoğurt', brand: 'Pınar', size: '1,5 kg' },
  { raw: 'BALKUPUTOZSEKER1KG', group: 'Şeker, toz', brand: 'Balküpü', size: '1 kg' },
  { raw: 'FILIZBURGUMAKARNA500G', group: 'Makarna, burgu', brand: 'Filiz', size: '500 g' },
  { raw: 'ERIKLISU5L', group: 'Su, doğal kaynak', brand: 'Erikli', size: '5 litre' },
  // Ürün adı üç harf ("SUT") ve markanın hemen ardında: yapışık metinde
  // kısa kelime aramak rastgele eşleşme ürettiği için bu satır hâlâ
  // soruluyor. Doğru aday tepede — yanlış bağlanmıyor.
  { raw: 'SUTASSUT1L', group: 'Süt, tam yağlı', brand: 'Sütaş', size: '1 litre' },
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
  // Grubu katalogda var ama MARKASI yok: bağlamak yanlış markaya yazmak olur.
  'IPEK TUZ 750G',
  'KINIK SIYAH ZEYTIN 400G',
  'DALIN BEBEK SAMPUANI 500ML',
  // Fişte marka hiç yazmıyor; katalogdaki ilk markaya bağlamak uydurmak olur.
  'BEBEK BEZI 4 NUMARA 30LU',
  // Marka katalogda var, ÜRÜN yok — en tehlikeli tür, çünkü marka güçlü
  // bir sinyal ve puanı tek başına yukarı çekiyor.
  'COLGATE DIS FIRCASI ORTA',
  'COLGATE GARGARA 500ML',
  'ULKER GOFRET 40G',
  'PINAR LABNE 200G',
  'ARKO TRAS KOPUGU 200ML',
  'LIPTON ICE TEA 1L',
  'NESTLE KAHVE KREMASI 400G',
  'BALPARMAK PEKMEZ 380G',
  'KOSKA LOKUM 350G',
  'DORITOS SOS 300G',
  // Yapışık yazım yanlış eşleşmeyi KOLAYLAŞTIRMAMALI. Belirteç markayı
  // içerdiği için tamamen karşılanmış sayılırsa fişte yazan "PEKMEZ"
  // ortadan kayboluyor ve puan boşluklu hâlinin üstüne çıkıyordu.
  'BALPARMAKPEKMEZ380G',
  'PINARLABNE200G',
  // Markası katalogda olmayan yapışık satır: A101'in kendi markası.
  // Kağıt havlu grubu katalogda var ama bunu Viva'ya bağlamak uydurmak
  // olur — doğru davranış sormak.
  'LOGIKAGITHAV12LI',
  // Katalogla hiç teması olmayan kalem.
  'MARLBORO TOUCH',
  'TADIM KURUYEMIS 150G',
];
