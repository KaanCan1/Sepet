-- Up Migration

-- Satırın boyunun neden o boy olduğu.
--
-- Fişte gramaj yazmadığı için boy şimdiye kadar ya kullanıcıya soruluyordu ya
-- da hiç çözülmüyordu. Referans fiyatlarla üçüncü bir yol açıldı: fişteki
-- fiyat, zincirin yayımladığı fiyatla kuruşu kuruşuna tutuyorsa boy
-- kanıtlanıyor.
--
-- Bu sütun o kanıtı satırda tutuyor. Sebebi ürünün kendi kuralı: uygulama
-- kullanıcıya sayının nereden geldiğini gösteriyor, gizlemiyor. Boy sessizce
-- seçilseydi, "gramaj asla tahmin edilmez" kuralı teknik olarak korunmuş ama
-- kullanıcı açısından bozulmuş olurdu — ekranda bir gramaj beliriyor ve
-- nereden geldiği söylenmiyor.
--
-- Yapılandırılmış tutuluyor, hazır cümle olarak değil: metni istemci kuruyor,
-- veritabanı olguyu tutuyor.
--
--   {"source": "marketfiyati.org.tr",
--    "title": "Viva Kağıt Havlu 6 Adet",
--    "price": 89.95,
--    "observedOn": "2026-09-09"}
--
-- Yalnızca referanstan çözülen satırlarda dolu. Alias'tan, katalogdan ya da
-- kullanıcıdan gelen eşleşmelerde NULL: onların kanıtı zaten belli.
ALTER TABLE receipt_lines
  ADD COLUMN match_evidence jsonb;

-- Down Migration

ALTER TABLE receipt_lines
  DROP COLUMN IF EXISTS match_evidence;
