-- Up Migration

-- Alias'ın kaynağı: kim, hangi ham metne, hangi ürün dedi.
--
-- SORUN ÖLÇÜLDÜ. product_aliases tek satır tutuyordu ve çakışmayı şöyle
-- çözüyordu:
--
--   DO UPDATE SET canonical_product_id = EXCLUDED.canonical_product_id,
--                 confirmations = confirmations + 1
--
-- Yani ikinci kullanıcı FARKLI bir ürün dediğinde cevabı üzerine yazıyor ve
-- sayacı da artırıyor. Denendi: iki kişi anlaşmadığı hâlde sayaç 2 yazıyor
-- ve ekranda yalnızca ikincinin cevabı duruyor. Sayaç, olmayan bir
-- mutabakatı iddia ediyor — ve hiçbir yerde okunmuyordu, yani yanlışlığı
-- bile fark edilmiyordu.
--
-- İkinci sorun: alias GLOBAL. Bir kullanıcının ilk cevabı anında herkesin
-- gerçeği oluyor. Tek kullanıcıda zararsız; uygulama yayımlandığında tek
-- yanlış cevap herkesin endeksini bozar, üstelik sessizce — yanlış ürün
-- yanlış birim fiyat, yanlış birim fiyat yanlış enflasyon.
--
-- ÇÖZÜM: oy. Her kullanıcının her ham metin için TEK oyu var; fikrini
-- değiştirirse oyu güncelleniyor, ikinci oy sayılmıyor.
--
-- product_aliases kalıyor ama artık TÜRETİLMİŞ: oyların kazananı. Fiş
-- kaydındaki okuma yolu değişmiyor, tek indeksli arama olarak kalıyor.
-- confirmations da artık doğru bir şey söylüyor — o ürüne kaç kullanıcının
-- katıldığı.
CREATE TABLE alias_votes (
  merchant_id          uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  raw_text_normalized  text NOT NULL,
  canonical_product_id uuid NOT NULL REFERENCES canonical_products(id) ON DELETE CASCADE,
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at           timestamptz NOT NULL DEFAULT now(),
  -- Kullanıcı başına tek oy. Aynı kişinin iki kez "onaylaması" mutabakat
  -- değil, tekrar.
  PRIMARY KEY (merchant_id, raw_text_normalized, user_id)
);

-- Kullanıcının kendi cevabı, fiş kaydında mutabakattan ÖNCE okunuyor:
-- kendi fişini kendi görmüş, paketi eline almış. Bu arama o yol için.
CREATE INDEX alias_votes_kendi_idx
  ON alias_votes (user_id, merchant_id, raw_text_normalized);

-- Mutabakat hesabı: bir ham metne verilen bütün oylar.
CREATE INDEX alias_votes_mutabakat_idx
  ON alias_votes (merchant_id, raw_text_normalized, canonical_product_id);

-- Var olan gerçek onaylar oya çevriliyor. Kim ne dediği fişten okunabiliyor:
-- onaylanmış satır + fişin sahibi + fişin marketi.
--
-- product_aliases'taki geri kalan satırlar tohumdan geliyor ve sahipleri
-- yok; oldukları gibi bırakılıyorlar. O ham metne ilk gerçek oy geldiğinde
-- mutabakat hesabı devralıyor — gerçek bir kullanıcının cevabı, tohum
-- verisinden daha iyi kanıt.
INSERT INTO alias_votes
  (merchant_id, raw_text_normalized, canonical_product_id, user_id, created_at)
SELECT r.merchant_id,
       normalize_raw_text(l.raw_text),
       l.canonical_product_id,
       r.user_id,
       l.created_at
  FROM receipt_lines l
  JOIN receipts r ON r.id = l.receipt_id
 WHERE l.status = 'confirmed'
   AND l.canonical_product_id IS NOT NULL
ON CONFLICT (merchant_id, raw_text_normalized, user_id) DO NOTHING;

-- Down Migration

DROP TABLE IF EXISTS alias_votes;
