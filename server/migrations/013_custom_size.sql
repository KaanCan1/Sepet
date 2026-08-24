-- Up Migration

-- Kullanıcının kendi gramajını girebilmesi.
--
-- Katalog rafta yaygın paketleri taşıyor ama hepsini taşıyamaz: Tacıroğlu'nun
-- 400 g'lık paketi listede yoksa kullanıcının yapabileceği tek şey yanlış bir
-- boy seçmek oluyordu — ve endeks birim fiyat üzerinden hesaplandığı için bu,
-- sessizce yanlış enflasyon demek.
--
-- Artık eksik boy uygulamadan eklenebiliyor. Eklenen kalem kataloğun kendisine
-- giriyor: aynı marka + grup + boy ikinci kez istendiğinde yenisi açılmıyor.
-- Bunun için tekillik kısıtı gerekiyordu; 008 modeli yeniden kurarken
-- (name, size_label) kısıtı düşmüş ve yerine bir şey konmamıştı.
--
-- brand_id NULL olabiliyor ve standart tekil indekste NULL'lar birbirinden
-- farklı sayılıyor — markasız iki "Domates kilogram" satırı yan yana
-- durabilirdi. PostgreSQL 15'in NULLS NOT DISTINCT'i bunu çözüyor ama
-- yerelde 14 var; ifade indeksi her iki sürümde de çalışıyor.
CREATE UNIQUE INDEX canonical_products_identity_idx
  ON canonical_products (
    group_id,
    coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid),
    size_label
  );

-- Down Migration
DROP INDEX IF EXISTS canonical_products_identity_idx;
