-- Up Migration

-- Referans fiyatlar: zincirlerin yayımladığı, kullanıcının fişinden GELMEYEN
-- fiyatlar.
--
-- Neden gerekiyor: yazarkasa metni gramaj basmıyor. Gerçek bir Migros fişinin
-- altı satırında eşleştirici beşinde doğru grubu ve markayı buluyor ama
-- hiçbirinde boyu bulamıyor — "MIGROS T.YAGLI YOGU." satırı 500 g da olabilir
-- 3 kg da. Bugün bu her satırda kullanıcıya soruluyor; yedi satırlık bir fiş
-- altı soru demek.
--
-- Fiş fiyatı yazıyor. Zincir de her boyun fiyatını yayımlıyor. İkisi
-- tutuyorsa boy TAHMİN edilmiş olmuyor, KANITLANMIŞ oluyor. Ölçüldü:
-- "VIVA HAVLU GLI" fişte 89,95; yayımlanan "Viva Kağıt Havlu 6 Adet" Migros'ta
-- 89,95. Birebir.
--
-- KRİTİK SINIR: bu fiyatlar endekse GİRMİYOR. Uygulamanın bütün iddiası
-- sayının kullanıcının kendi fişinden geldiği. Laspeyres hesabına dışarıdan
-- bir fiyat karıştırmak, ürünün var olma sebebi olan yalanı yapmak olur.
-- Bu tablo yalnızca "hangi boy?" sorusunu cevaplamak için okunuyor;
-- price_observations'a hiçbir satır yazmıyor. Ayrı tablo olmasının sebebi de
-- bu: karışma imkânsız olsun.
CREATE TABLE reference_prices (
  canonical_product_id uuid        NOT NULL REFERENCES canonical_products(id) ON DELETE CASCADE,
  merchant_id          uuid        NOT NULL REFERENCES merchants(id)          ON DELETE CASCADE,
  -- Fiyatın kaynakta göründüğü gün. Anahtarın parçası: fiyat her gün
  -- değişiyor ve geçmişi tutmak istiyoruz — geriye dönük alınamayan tek şey
  -- bu, toplanmayan günün verisi kalıcı olarak kayıp.
  observed_on          date        NOT NULL,
  price                numeric(12,2) NOT NULL CHECK (price > 0),
  -- Nereden geldiği. Bugün tek kaynak var ama kaynağı satırda tutmak,
  -- ileride ikincisi eklendiğinde hangi fiyata güvenileceğini seçilebilir
  -- kılıyor.
  source               text        NOT NULL,
  -- Kaynaktaki ürünün kimliği. Anahtarın parçası, çünkü aynı marka-grup-boy
  -- üçlüsüne birden çok kaynak ürünü düşebiliyor: "Sütaş Yoğurt 1 kg" 99,50
  -- ve "Sütaş Kaymaksız Yoğurt 1 kg" 87,50 — ikisi de bizim tek kalemimize
  -- denk geliyor. Birini seçip diğerini atmak, fişteki fiyat atılanınkiyse
  -- eşleşmeyi kaçırmak demek. Hepsi duruyor.
  --
  -- Çeşit belirsizliği boyu belirsiz yapmıyor: ikisi de 1 kg. Bu tablo
  -- yalnızca boy sorusunu cevapladığı için çeşide karşı dayanıklı.
  source_ref           text        NOT NULL,
  -- Kaynaktaki ürün başlığı, olduğu gibi. Denetim için: yanlış eşlenmiş bir
  -- referans, sessizce yanlış boy seçtirir. Başlık satırda dururken bir insan
  -- "Viva Kağıt Havlu 6 Adet gerçekten bizim 6'lı kalemimiz mi" diye
  -- bakabiliyor.
  source_title         text        NOT NULL,
  fetched_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (canonical_product_id, merchant_id, observed_on, source_ref)
);

-- Çözücünün sorgusu: "şu üründe, şu zincirde, şu tarihe yakın fiyat".
CREATE INDEX reference_prices_lookup_idx
  ON reference_prices (merchant_id, observed_on DESC);

-- Down Migration

DROP TABLE IF EXISTS reference_prices;
