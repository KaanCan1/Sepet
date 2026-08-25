-- Up Migration

-- Marka tutuyorsa aday listesine girsin.
--
-- Süzgeç "grup adından en az bir kelime geçsin ya da trigram benzerliği
-- olsun" diyordu. Bu, marka apaçık eşleştiği hâlde bazı kalemleri listeden
-- tamamen siliyordu:
--
--   ARIEL SIVI 3 LT    ->  hiç aday yok
--   KOMILI RIVIERA 1L  ->  hiç aday yok
--
-- Katalogdaki karşılıkları "Ariel Deterjan, çamaşır 3 litre" ve "Komili
-- Zeytinyağı 1 litre". Fiş grup adını hiç yazmıyor — yazarkasa markayı ve
-- ürün hattını basıyor, kategoriyi değil. Ortak kelime olmayınca kalem
-- eleniyor ve kullanıcı boş bir öneri listesiyle kalıyordu; oysa marka tek
-- başına zayıf değil, sadece tek başına YETERLİ değil.
--
-- Aday listesine girmek bağlanmak demek değil: puan yine düşük kalıyor ve
-- otomatik eşleşme eşiğini geçmiyor. Değişen şey, kullanıcının arama
-- kutusuna kelime yazmak yerine listedeki satıra dokunması.

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
   WHERE group_cov > 0 OR trgm > 0.25
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$fn$;
