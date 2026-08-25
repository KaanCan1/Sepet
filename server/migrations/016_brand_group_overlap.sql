-- Up Migration

-- Marka bir kez puanlansın.
--
-- Grup kapsaması ham metindeki belirteçlere bakıyordu ama belirtecin
-- markadan mı yoksa ürün adından mı geldiğine bakmıyordu. Marka adı grup
-- adıyla başlıyorsa aynı kelime iki kez puanlanıyordu:
--
--   BALPARMAK PEKMEZ 380G  ->  Balparmak Bal  0.731
--
-- "BALPARMAK" hem marka eşleşmesini veriyor hem de "BAL" grubunu tam
-- kapsıyor. Oysa fişte pekmez yazıyor ve pekmez bal değil. Puan eşiğin
-- epey üstünde; kalemi yanlış bağlanmaktan koruyan tek şey boyun
-- tutmaması olmuştu — yani tesadüf.
--
-- Aynı tuzak "Torku Şeker / Şeker, toz", "Pınar Et / Et" gibi marka adının
-- ürün adını içerdiği her yerde kurulu.

CREATE OR REPLACE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $fn$
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
                          -- Markanın karşıladığı belirteç grubu da
                          -- karşılamış sayılmıyor; aksi hâlde marka iki
                          -- kez puanlanıyor.
                          AND NOT EXISTS (
                                SELECT 1
                                  FROM unnest(
                                    to_tokens(coalesce(v.brand_name, ''))) bt2
                                 WHERE token_prefix_match(rt, bt2)
                              )
                     ) THEN 1.0 ELSE 0.0 END),
                 0.0)
          FROM unnest(to_tokens(v.group_name)) gt
      ) AS group_cov,
      raw_coverage(p_raw, coalesce(v.brand_name, '') || ' ' || v.group_name)
        AS raw_cov,
      similarity(r.flat, normalize_raw_text(v.display_name)) AS trgm
      FROM v_canonical_products v, raw r
  )
  SELECT id,
         round(
           CASE
             WHEN brand_hit IS NULL
               THEN 0.40 * group_cov + 0.44 * raw_cov + 0.16 * trgm
             ELSE 0.25 * brand_hit + 0.25 * group_cov
                  + 0.38 * raw_cov + 0.12 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25 OR brand_hit = 1.0
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$fn$;

-- Down Migration
CREATE OR REPLACE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $fn$
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
  SELECT id,
         round(
           CASE
             WHEN brand_hit IS NULL
               THEN 0.40 * group_cov + 0.44 * raw_cov + 0.16 * trgm
             ELSE 0.25 * brand_hit + 0.25 * group_cov
                  + 0.38 * raw_cov + 0.12 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25 OR brand_hit = 1.0
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$fn$;
