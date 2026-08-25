-- Up Migration

-- Puanlamaya dördüncü sinyal: ham metnin ne kadarı ürünle açıklanıyor.
--
-- Eksik olan buydu. Üç sinyalin üçü de "ürün ham metinde var mı" diye
-- soruyordu; hiçbiri "ham metinde ürünle ilgisi olmayan ne var" diye
-- sormuyordu. Sonuç ölçülebilir bir hata:
--
--   LAYS PATATES CIPSI 150G  ->  Patates kilogram   0.811
--
-- Grup adı tek kelime ("Patates") ve o kelime ham metinde geçiyor, yani
-- grup kapsaması tam. LAYS ve CIPSI hiçbir yere yazılmıyordu. Cips patates
-- değil ve bu satırın kilo fiyatı endekse girerse sessizce yanlış enflasyon
-- üretiyor.
--
-- Boy belirteçleri paydanın dışında: "150G" ürünle eşleşmez ama eşleşmesi
-- de beklenmiyor — boyu ayrı bir mekanizma (size-hint.ts) okuyor. Üç harften
-- kısa belirteçler de dışarıda, çünkü token_prefix_match zaten onları
-- eşleştirmiyor ve paydada durmaları her ürünü haksız yere cezalandırır.
CREATE FUNCTION raw_coverage(p_raw text, p_product text) RETURNS numeric
LANGUAGE sql IMMUTABLE STRICT AS $$
  WITH kelime AS (
    SELECT rt FROM unnest(to_tokens(p_raw)) rt
     WHERE length(rt) >= 3
       AND rt !~ '^[0-9]'
       AND rt NOT IN ('ADET','PAKET','KUTU','LITRE','GRAM','SISE','TENEKE')
  )
  SELECT coalesce(
           avg(CASE WHEN EXISTS (
                 SELECT 1 FROM unnest(to_tokens(p_product)) pt
                  WHERE token_prefix_match(rt, pt)
               ) THEN 1.0 ELSE 0.0 END),
           -- Kelime yoksa cezalandıracak bir şey de yok.
           1.0)::numeric
    FROM kelime
$$;

CREATE OR REPLACE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $$
  WITH raw AS (
    SELECT to_tokens(p_raw) AS toks, normalize_raw_text(p_raw) AS flat
  ),
  scored AS (
    SELECT
      v.id,
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
      (
        SELECT coalesce(
                 avg(CASE WHEN EXISTS (
                       SELECT 1 FROM unnest(r.toks) rt
                        WHERE token_prefix_match(rt, gt)
                     ) THEN 1.0 ELSE 0.0 END),
                 0.0)
          FROM unnest(to_tokens(v.group_name)) gt
      ) AS group_cov,
      raw_coverage(p_raw, coalesce(v.brand_name, '') || ' ' || v.group_name)
        AS raw_cov,
      similarity(r.flat, normalize_raw_text(v.display_name)) AS trgm
      FROM v_canonical_products v, raw r
  )
  -- Ağırlıklar göz kararı değil, ölçüyle seçildi: etiketli küme ve
  -- düşmanca olumsuz vakalar üzerinde tarandı (scripts/match-eval.ts).
  -- Ham kapsamanın payını daha da büyütmek (0.44) sonucu kötüleştiriyor —
  -- gerçek ürün adlarında katalogun modellemediği kelimeler var
  -- ("Elma STARKING", "Muz İTHAL", "Çaykur RIZE TURIST") ve fazla ceza
  -- doğru eşleşmeleri de eliyor.
  SELECT id,
         round(
           CASE
             WHEN brand_hit IS NULL
               -- Markasız ürün: marka payı kalanlara dağılıyor.
               THEN 0.40 * group_cov + 0.44 * raw_cov + 0.16 * trgm
             ELSE 0.25 * brand_hit + 0.25 * group_cov
                  + 0.38 * raw_cov + 0.12 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$$;

-- Down Migration
CREATE OR REPLACE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $$
  WITH raw AS (
    SELECT to_tokens(p_raw) AS toks, normalize_raw_text(p_raw) AS flat
  ),
  scored AS (
    SELECT
      v.id,
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
               THEN 0.75 * group_cov + 0.25 * trgm
             ELSE 0.40 * brand_hit + 0.45 * group_cov + 0.15 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$$;
DROP FUNCTION IF EXISTS raw_coverage (text, text);
