-- Up Migration

-- Ürün havuzu: zincirlerin sattığı her şey.
--
-- Katalog (product_groups + canonical_products) bir ÜRÜN LİSTESİ DEĞİL, bir
-- TÜFE SEPETİ. Doksan altı grup, ağırlıklarıyla birlikte, aylar arası
-- kıyaslanabilir olsun diye seçilmiş. Ölçüldü: kaynaktan örneklenen sekiz
-- kategoriden altısının sepette karşılığı yok — Pet Shop, Konserve,
-- Kuruyemiş, Hazır Yemekler, Gofret, Baharat.
--
-- Sonucu şuydu: sepet dışındaki bir fiş satırı HİÇ eşleşemiyor, alias da
-- öğrenilemiyor — gösterilecek bir hedef yok. O satır sonsuza kadar
-- "eşleşme bekliyor" kalıyor ve kullanıcının gördüğü şey "uygulama benim
-- fişimi anlamıyor" oluyor.
--
-- İKİ KATMAN, BİR KÖPRÜ.
--
--   Havuz (bu tablo)  — işi TANIMAK. "MIGROS T.YAGLI YOGU." satırının
--                       "Migros Tam Yağlı Yoğurt 1 Kg" olduğunu, markası ve
--                       GRAMAJIYLA birlikte söylemek. Serbestçe büyüyor.
--   Sepet (katalog)   — işi ÖLÇMEK. Laspeyres, ağırlıklar, kıyaslanabilirlik.
--                       Elle ve ağırlığıyla birlikte büyüyor.
--
-- Köprü aşağıdaki canonical_product_id ve BOŞ BIRAKILABİLİR olması kasıtlı.
-- Üç durum doğuruyor ve üçüncüsü asıl kazanç:
--
--   dolu   → satır tanındı ve endekse giriyor
--   boş    → satır TANINDI ama endekse girmiyor: kullanıcı ürünün adını,
--            markasını ve gramajını görüyor, uygulama da onu neden
--            saymadığını söyleyebiliyor
--   kayıt yok → gerçekten bilinmiyor, kullanıcıya soruluyor
--
-- Bugün yalnızca birinci ve üçüncü durum var. İkincisi bekleyen satır
-- gürültüsünün büyük kısmını kaldırıyor.
--
-- HAVUZ NEDEN SEPETE KARIŞMIYOR: elli bin kalemi endekse sokmak Laspeyres'i
-- anlamsızlaştırırdı. Sabit ve ağırlıklı bir sepet gerekiyor; basket_weights
-- tam da bunun için var. Bu tablodaki hiçbir satır kendiliğinden sepete
-- girmiyor.
CREATE TABLE pool_products (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Nereden geldiği ve oradaki kimliği. İkisi birlikte tekil: aynı ürün
  -- yeniden çekilince satır güncelleniyor, çoğalmıyor.
  source       text NOT NULL,
  source_ref   text NOT NULL,

  -- Kaynaktaki başlık, olduğu gibi: "Migros Tam Yağlı Yoğurt 1 Kg".
  title        text NOT NULL,

  -- Eşleştirmenin arayacağı düzlem. Üretilen sütun, çünkü başlıktan türüyor
  -- ve ikisinin ayrışması imkânsız olmalı; normalize_raw_text IMMUTABLE.
  title_normalized text GENERATED ALWAYS AS (normalize_raw_text(title)) STORED,

  -- Kaynağın kendi marka dizesi. brands tablosuna BAĞLANMIYOR: havuz
  -- kaynağın sözlüğünü konuşuyor, bizimkini değil. Bağlama işi köprüde.
  brand_text   text,

  -- "400 GR", "1 LT". Ham hâli saklanıyor çünkü kayıpsız; ayrıştırılmışı
  -- yanında duruyor ve ayrıştırılamadıysa NULL — uydurulmuyor.
  size_text    text,
  size_value   numeric(12,4) CHECK (size_value IS NULL OR size_value > 0),
  unit         product_unit,

  main_category text,

  -- Köprü. ON DELETE SET NULL: sepetten bir kalem çıkarılırsa havuz kaydı
  -- silinmiyor, yalnızca endeks dışına düşüyor.
  canonical_product_id uuid REFERENCES canonical_products(id) ON DELETE SET NULL,

  first_seen_on date NOT NULL DEFAULT current_date,
  -- Ürün kaynaktan kalkarsa bunu görebilmek için. Silmiyoruz: geçmiş fişler
  -- hâlâ o ürüne bakıyor olabilir.
  last_seen_on  date NOT NULL DEFAULT current_date,

  UNIQUE (source, source_ref)
);

-- Yazarkasa metni başlığın kısaltılmışı ("MIGROS EKSTRA CECIL" <-
-- "Migros Ekstra Çeçil Peyniri 200 Gr"). Ön ek araması bu yüzden
-- text_pattern_ops ile.
CREATE INDEX pool_products_title_prefix_idx
  ON pool_products (title_normalized text_pattern_ops);

-- Sepete bağlı kalemler: köprüden endekse giden yol.
CREATE INDEX pool_products_canonical_idx
  ON pool_products (canonical_product_id)
  WHERE canonical_product_id IS NOT NULL;

-- Down Migration

DROP TABLE IF EXISTS pool_products;
