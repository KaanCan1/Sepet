-- Up Migration

-- Bulanık katalog eşleştirme.
--
-- Şimdiye kadar eşleştirme iki uçtan biriydi: ham metin alias tablosunda
-- birebir varsa otomatik, yoksa kullanıcıya soruluyordu. Arada hiçbir şey
-- yoktu. Oysa yazarkasa ürün adını kolona sığdırmak için kesiyor —
-- "MIGROS T.YAGLI YOGU." katalogdaki "Migros Yoğurt 1 kg" ile hiçbir
-- substring aramasında buluşmuyor, ama insan gözüyle apaçık aynı şey.
--
-- Buradaki puanlama üç sinyali topluyor. Hiçbiri tek başına yeterli değil:
-- trigram benzerliği kesilmiş adlarda düşük kalıyor, marka eşleşmesi tek
-- başına "Sütaş"ın on ürününü ayırt etmiyor, grup kapsaması markasız
-- kalemleri karıştırıyor.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- İki belirteç aynı kelimenin parçası mı?
--
-- Kesilme her zaman sondan oluyor ("YOGURT" -> "YOGU"), o yüzden önek
-- ilişkisi yeterli. Üç harf alt sınırı var: "T" ile "TAVUK" eşleşirse
-- puanlama çöpe döner.
CREATE FUNCTION token_prefix_match(a text, b text) RETURNS boolean
LANGUAGE sql IMMUTABLE STRICT AS $$
  SELECT length(a) >= 3 AND length(b) >= 3
     AND (a LIKE b || '%' OR b LIKE a || '%')
$$;

CREATE FUNCTION to_tokens(p_text text) RETURNS text[]
LANGUAGE sql IMMUTABLE STRICT AS $$
  SELECT array_remove(
           string_to_array(btrim(normalize_raw_text(p_text)), ' '),
           ''
         )
$$;

-- Ham fiş metnine en yakın kanonik ürünler, puanlarıyla.
--
-- Puan 0..1. Ağırlıklar iki gerçek fiş üzerinde ayarlandı (24.08.2026
-- tarihli BİM ve Migros e-arşiv faturaları):
--
--   0.40  marka — fişte marka neredeyse hep tam yazılıyor, kesilen ürün adı
--   0.45  grup kapsaması — "YOGU" ile "Yoğurt" burada buluşuyor
--   0.15  trigram — yazım hatalarına karşı yastık ("TACIROGLI"/"Tacıroğlu")
--
-- Markası olmayan kanonik ürünlerde (Domates, Yumurta …) marka payı
-- kayıptır; bunlarda grup kapsaması tek başına taşıyor, bu yüzden marka
-- sinyali yokken kalan iki bileşen yukarı ölçekleniyor.
CREATE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $$
  WITH raw AS (
    SELECT to_tokens(p_raw) AS toks, normalize_raw_text(p_raw) AS flat
  ),
  scored AS (
    SELECT
      v.id,
      -- Marka belirteçlerinden biri ham metinde geçiyor mu?
      CASE
        WHEN v.brand_name IS NULL THEN NULL
        WHEN EXISTS (
          SELECT 1
            FROM unnest(to_tokens(v.brand_name)) bt,
                 unnest(r.toks) rt
           WHERE token_prefix_match(rt, bt)
        ) THEN 1.0
        ELSE 0.0
      END AS brand_hit,
      -- Grup adının kaç belirteci ham metinde karşılanıyor?
      (
        SELECT coalesce(
                 avg(CASE WHEN EXISTS (
                       SELECT 1 FROM unnest(r.toks) rt
                        WHERE token_prefix_match(rt, gt)
                     ) THEN 1.0 ELSE 0.0 END),
                 0.0)
          FROM unnest(to_tokens(v.group_name)) gt
      ) AS group_cov,
      similarity(r.flat, normalize_raw_text(v.display_name)) AS trgm
      FROM v_canonical_products v, raw r
  )
  SELECT id,
         round(
           CASE
             WHEN brand_hit IS NULL
               -- Markasız ürün: 0.40'lık marka payı kalan ikisine dağılıyor.
               THEN 0.75 * group_cov + 0.25 * trgm
             ELSE 0.40 * brand_hit + 0.45 * group_cov + 0.15 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$$;

-- Down Migration
DROP FUNCTION IF EXISTS catalog_match (text, integer);
DROP FUNCTION IF EXISTS to_tokens (text);
DROP FUNCTION IF EXISTS token_prefix_match (text, text);
