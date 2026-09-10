-- Up Migration

-- Satırın havuzdaki karşılığı.
--
-- canonical_product_id "bu satır endekste hangi kalem" sorusunun cevabı ve
-- sepet dışı ürünlerde boş kalmak zorunda. Ama satırın NE OLDUĞU o zaman da
-- biliniyor — havuzdaki kalem. İki soru ayrı, iki sütun ayrı.
--
-- Buradan gelen tek şey ekranda görünen ad: kullanıcı "VIVA HAVLU GLI"
-- yerine "Viva Kağıt Havlu 6 Adet" okuyor. Endeks bu sütunu HİÇ okumuyor;
-- endeksin tek girdisi kullanıcının kendi fişindeki tutar ve o tutarın
-- bağlandığı kanonik kalem.
--
-- ON DELETE SET NULL: havuz kaynaktan gelen bir veri ve yeniden kurulabilir.
-- Bir havuz kalemi düşerse satır kaybolmuyor, yalnızca adını kaybediyor.
ALTER TABLE receipt_lines
  ADD COLUMN pool_product_id uuid REFERENCES pool_products(id) ON DELETE SET NULL;

-- Down Migration

ALTER TABLE receipt_lines
  DROP COLUMN IF EXISTS pool_product_id;
