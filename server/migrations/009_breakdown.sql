-- Up Migration

-- Kategori ve marka kırılımı.
--
-- Aynı zincirleme, kısıtlanmış küme üzerinde: ağırlıklar küme içinde yeniden
-- normalize ediliyor ki her kırılım kendi içinde %100 etsin.
--
--   L_küme,t = Σ w_i,t · (p_i,t/p_i,t-1) ⁄ Σ w_i,t     i ∈ M_t ∩ küme
--
-- Kümülatif çarpım penceresi Postgres'te yok; exp(Σ ln) ile alınıyor.

-- Ürün bazında aylık oran ve ağırlık — üç kırılımın ortak girdisi.
CREATE VIEW v_monthly_relatives AS
SELECT cur.user_id,
       cur.month,
       cur.canonical_product_id,
       p.category_id,
       p.brand_id,
       p.group_id,
       cur.unit_price / prev.unit_price AS relative,
       coalesce(w.weight, 0)            AS weight
  FROM monthly_product_prices cur
  JOIN monthly_product_prices prev
    ON prev.user_id = cur.user_id
   AND prev.canonical_product_id = cur.canonical_product_id
   AND prev.month = cur.month - interval '1 month'
   AND prev.unit_price > 0
  JOIN v_canonical_products p ON p.id = cur.canonical_product_id
  LEFT JOIN basket_weights w
    ON w.user_id = cur.user_id
   AND w.canonical_product_id = cur.canonical_product_id
   AND w.as_of_month = cur.month;

CREATE VIEW v_index_by_category AS
WITH links AS (
  SELECT user_id, category_id, month,
         sum(weight)                                   AS covered_weight,
         CASE WHEN sum(weight) > 0
              THEN sum(weight * relative) / sum(weight)
              ELSE 1 END                               AS link
    FROM v_monthly_relatives
   GROUP BY user_id, category_id, month
)
SELECT l.user_id,
       l.category_id,
       c.code  AS category_code,
       c.name  AS category_name,
       l.month,
       round(l.link, 8) AS link,
       round(
         100 * exp(sum(ln(l.link)) OVER (
           PARTITION BY l.user_id, l.category_id ORDER BY l.month
         )), 4
       ) AS level,
       round(l.covered_weight, 6) AS covered_weight
  FROM links l
  JOIN categories c ON c.id = l.category_id;

CREATE VIEW v_index_by_brand AS
WITH links AS (
  SELECT user_id, brand_id, month,
         sum(weight)                                   AS covered_weight,
         CASE WHEN sum(weight) > 0
              THEN sum(weight * relative) / sum(weight)
              ELSE 1 END                               AS link
    FROM v_monthly_relatives
   WHERE brand_id IS NOT NULL
   GROUP BY user_id, brand_id, month
)
SELECT l.user_id,
       l.brand_id,
       b.name AS brand_name,
       l.month,
       round(l.link, 8) AS link,
       round(
         100 * exp(sum(ln(l.link)) OVER (
           PARTITION BY l.user_id, l.brand_id ORDER BY l.month
         )), 4
       ) AS level,
       round(l.covered_weight, 6) AS covered_weight
  FROM links l
  JOIN brands b ON b.id = l.brand_id;

-- Aynı grup + boyda markalar arası fiyat farkı: "1,5 kg yoğurt kimde kaça".
-- En son görülen fiyatı esas alıyor; endeksle ilgisi yok, karşılaştırma için.
CREATE VIEW v_group_price_spread AS
SELECT p.group_id,
       p.group_name,
       p.size_value,
       p.size_label,
       latest.user_id,
       p.id           AS canonical_product_id,
       p.brand_name,
       latest.unit_price,
       latest.pack_price,
       latest.observed_on,
       m.name         AS merchant_name
  FROM v_canonical_products p
  JOIN LATERAL (
    SELECT DISTINCT ON (o.user_id) o.user_id, o.unit_price, o.pack_price,
           o.observed_on, o.merchant_id
      FROM price_observations o
     WHERE o.canonical_product_id = p.id AND NOT o.is_outlier
     ORDER BY o.user_id, o.observed_on DESC
  ) AS latest ON true
  JOIN merchants m ON m.id = latest.merchant_id;

-- Down Migration
DROP VIEW IF EXISTS v_group_price_spread;
DROP VIEW IF EXISTS v_index_by_brand;
DROP VIEW IF EXISTS v_index_by_category;
DROP VIEW IF EXISTS v_monthly_relatives;
