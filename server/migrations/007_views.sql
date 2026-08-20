-- Up Migration

-- Ekran 01 manşeti: son 12 ayda senin sepetin.
--
-- 12 ay dolmamışsa yıllıklandırma YAPILMAZ — mevcut en eski aya göre gerçek
-- değişim ve pencerenin kaç ay olduğu döner. Ekrandaki "SON 12 AY" etiketi
-- window_months'a göre yazılır.
CREATE VIEW v_index_headline AS
WITH latest AS (
  SELECT DISTINCT ON (user_id) user_id, month, level, covered_weight
    FROM index_levels ORDER BY user_id, month DESC
),
base AS (
  SELECT l.user_id, l.month AS current_month, l.level AS current_level,
         l.covered_weight,
         b.month AS base_month, b.level AS base_level
    FROM latest l
    CROSS JOIN LATERAL (
      -- 12 ay öncesi varsa onu, yoksa serinin en eskisini al.
      SELECT month, level FROM index_levels il
       WHERE il.user_id = l.user_id
         AND il.month >= l.month - interval '12 months'
       ORDER BY il.month ASC
       LIMIT 1
    ) AS b
)
SELECT user_id,
       current_month,
       base_month,
       -- Kaç aylık pencereye bakıldığı.
       (EXTRACT(YEAR FROM age(current_month, base_month)) * 12
        + EXTRACT(MONTH FROM age(current_month, base_month)))::int AS window_months,
       round((current_level / nullif(base_level, 0) - 1) * 100, 1) AS change_pct,
       round(covered_weight, 4) AS covered_weight
  FROM base;

-- Ekran 01 grafiği: senin serin. Resmî seriler ayrı sorgulanıp yan yana konur.
CREATE VIEW v_index_series AS
SELECT user_id, month, round(level, 4) AS level,
       round((link - 1) * 100, 2) AS mom_pct,
       round(covered_weight, 4) AS covered_weight
  FROM index_levels;

-- Ekran 03: bir ürünün gözlem geçmişi ve özeti.
CREATE VIEW v_product_summary AS
SELECT o.user_id,
       o.canonical_product_id,
       cp.name,
       cp.size_label,
       count(*)::int                        AS observations,
       count(DISTINCT o.merchant_id)::int   AS merchant_count,
       min(o.observed_on)                   AS first_seen,
       max(o.observed_on)                   AS last_seen,
       (EXTRACT(YEAR FROM age(max(o.observed_on), min(o.observed_on))) * 12
        + EXTRACT(MONTH FROM age(max(o.observed_on), min(o.observed_on))))::int
                                            AS month_span,
       (array_agg(o.pack_price ORDER BY o.observed_on ASC))[1]  AS first_pack_price,
       (array_agg(o.pack_price ORDER BY o.observed_on DESC))[1] AS last_pack_price,
       (array_agg(o.unit_price ORDER BY o.observed_on ASC))[1]  AS first_unit_price,
       (array_agg(o.unit_price ORDER BY o.observed_on DESC))[1] AS last_unit_price
  FROM price_observations o
  JOIN canonical_products cp ON cp.id = o.canonical_product_id
 WHERE NOT o.is_outlier
 GROUP BY o.user_id, o.canonical_product_id, cp.name, cp.size_label;

-- Ekran 03 alt kısmı: her markette EN SON görülen fiyat.
CREATE VIEW v_product_by_merchant AS
SELECT DISTINCT ON (o.user_id, o.canonical_product_id, o.merchant_id)
       o.user_id, o.canonical_product_id, o.merchant_id,
       m.name AS merchant_name, o.pack_price, o.unit_price, o.observed_on
  FROM price_observations o
  JOIN merchants m ON m.id = o.merchant_id
 WHERE NOT o.is_outlier
 ORDER BY o.user_id, o.canonical_product_id, o.merchant_id, o.observed_on DESC;

-- Ekran 04: bu ay en çok zamlananlar.
--
-- Yalnızca HER İKİ ayda da gerçek gözlemi olan ürünler girer. Taşınmış fiyat
-- "zam yapmadı" der; onu listeye almak yanlış olurdu. Ağırlık eşiği de var:
-- sepette payı olmayan kalem manşete çıkmasın.
CREATE VIEW v_monthly_movers AS
SELECT cur.user_id,
       cur.month,
       cur.canonical_product_id,
       cp.name,
       cp.size_label,
       round((cur.unit_price / prev.unit_price - 1) * 100, 1) AS change_pct,
       w.weight
  FROM monthly_product_prices cur
  JOIN monthly_product_prices prev
    ON prev.user_id = cur.user_id
   AND prev.canonical_product_id = cur.canonical_product_id
   AND prev.month = cur.month - interval '1 month'
  JOIN canonical_products cp ON cp.id = cur.canonical_product_id
  LEFT JOIN basket_weights w
    ON w.user_id = cur.user_id
   AND w.canonical_product_id = cur.canonical_product_id
   AND w.as_of_month = cur.month
 WHERE NOT cur.is_imputed
   AND NOT prev.is_imputed
   AND prev.unit_price > 0
   AND coalesce(w.weight, 0) >= (SELECT mover_min_weight FROM index_settings WHERE id);

-- Down Migration
DROP VIEW IF EXISTS v_monthly_movers;
DROP VIEW IF EXISTS v_product_by_merchant;
DROP VIEW IF EXISTS v_product_summary;
DROP VIEW IF EXISTS v_index_series;
DROP VIEW IF EXISTS v_index_headline;
