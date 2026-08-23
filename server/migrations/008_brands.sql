-- Up Migration

-- Ürün kimliğindeki üç kavram tek tabloda iç içeydi: ne olduğu, kimin
-- ürettiği, kaçlık paket. Ayrıştırılıyor.

-- Ne olduğu. Kategori ve kanonik birim burada: bir grubun tek birimi olur,
-- yoksa aynı grubun litre ve kilogram karışırdı.
CREATE TABLE product_groups (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL UNIQUE,          -- "Süt, tam yağlı"
  unit        product_unit NOT NULL,
  category_id uuid NOT NULL REFERENCES categories (id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX product_groups_category_idx ON product_groups (category_id);

-- Kimin ürettiği. normalized_name OCR eşleşmesi için; normalize_raw_text ile
-- aynı kuralı kullanıyor ki fişten okunan "SUTAS" buraya düşebilsin.
CREATE TABLE brands (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,             -- "Sütaş"
  normalized_name text NOT NULL UNIQUE,      -- "SUTAS"
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Görünen adı üreten view'lar bu sütunlara bağlı; önce düşürülüp sonda
-- yeniden kuruluyorlar.
DROP VIEW IF EXISTS v_monthly_movers;
DROP VIEW IF EXISTS v_product_by_merchant;
DROP VIEW IF EXISTS v_product_summary;

ALTER TABLE canonical_products
  ADD COLUMN group_id uuid REFERENCES product_groups (id) ON DELETE RESTRICT,
  ADD COLUMN brand_id uuid REFERENCES brands (id) ON DELETE RESTRICT;

-- Mevcut kalemler markasız jenerik adlar ("Süt, tam yağlı"); her biri kendi
-- grubuna taşınıyor, marka boş kalıyor.
INSERT INTO product_groups (name, unit, category_id)
SELECT DISTINCT name, unit, category_id FROM canonical_products
ON CONFLICT (name) DO NOTHING;

UPDATE canonical_products cp
   SET group_id = g.id
  FROM product_groups g
 WHERE g.name = cp.name;

ALTER TABLE canonical_products
  ALTER COLUMN group_id SET NOT NULL,
  DROP CONSTRAINT canonical_products_name_size_label_key,
  DROP COLUMN name,
  DROP COLUMN unit,
  DROP COLUMN category_id,
  DROP COLUMN substitute_group_id;

-- Aynı grup + marka + boy tek kalem. Marka NULL olabildiği için tekil indeks
-- iki parçaya bölünüyor: NULL'lar UNIQUE kısıtında eşit sayılmaz.
CREATE UNIQUE INDEX canonical_products_branded_key
  ON canonical_products (group_id, brand_id, size_value)
  WHERE brand_id IS NOT NULL;
CREATE UNIQUE INDEX canonical_products_unbranded_key
  ON canonical_products (group_id, size_value)
  WHERE brand_id IS NULL;

CREATE INDEX canonical_products_group_idx ON canonical_products (group_id);
CREATE INDEX canonical_products_brand_idx ON canonical_products (brand_id)
  WHERE brand_id IS NOT NULL;

-- Görünen ad saklanmıyor, türetiliyor: "Sütaş Süt, tam yağlı 1 litre".
CREATE VIEW v_canonical_products AS
SELECT cp.id,
       cp.group_id,
       cp.brand_id,
       g.name        AS group_name,
       g.unit,
       g.category_id,
       b.name        AS brand_name,
       cp.size_label,
       cp.size_value,
       -- İki ad: biri boyla, biri boysuz. İstemci adı ve boyu ayrı
       -- gösteriyor ("Sütaş Yoğurt" + "1,5 kg"); tek alanda birleşik ad
       -- döndürülürse boy iki kez yazılıyor.
       trim(coalesce(b.name || ' ', '') || g.name)
                     AS short_name,
       trim(
         coalesce(b.name || ' ', '') || g.name || ' ' || cp.size_label
       )             AS display_name
  FROM canonical_products cp
  JOIN product_groups g ON g.id = cp.group_id
  LEFT JOIN brands b ON b.id = cp.brand_id;

-- ── View'lar yeniden ───────────────────────────────────────────────────────
CREATE VIEW v_product_summary AS
SELECT o.user_id,
       o.canonical_product_id,
       p.short_name                         AS name,
       p.group_name,
       p.brand_name,
       p.size_label,
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
  JOIN v_canonical_products p ON p.id = o.canonical_product_id
 WHERE NOT o.is_outlier
 GROUP BY o.user_id, o.canonical_product_id,
          p.short_name, p.group_name, p.brand_name, p.size_label;

CREATE VIEW v_product_by_merchant AS
SELECT DISTINCT ON (o.user_id, o.canonical_product_id, o.merchant_id)
       o.user_id, o.canonical_product_id, o.merchant_id,
       m.name AS merchant_name, o.pack_price, o.unit_price, o.observed_on
  FROM price_observations o
  JOIN merchants m ON m.id = o.merchant_id
 WHERE NOT o.is_outlier
 ORDER BY o.user_id, o.canonical_product_id, o.merchant_id, o.observed_on DESC;

CREATE VIEW v_monthly_movers AS
SELECT cur.user_id,
       cur.month,
       cur.canonical_product_id,
       p.short_name AS name,
       p.size_label,
       p.brand_name,
       round((cur.unit_price / prev.unit_price - 1) * 100, 1) AS change_pct,
       w.weight
  FROM monthly_product_prices cur
  JOIN monthly_product_prices prev
    ON prev.user_id = cur.user_id
   AND prev.canonical_product_id = cur.canonical_product_id
   AND prev.month = cur.month - interval '1 month'
  JOIN v_canonical_products p ON p.id = cur.canonical_product_id
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
DROP VIEW IF EXISTS v_canonical_products;

DROP INDEX IF EXISTS canonical_products_brand_idx;
DROP INDEX IF EXISTS canonical_products_group_idx;
DROP INDEX IF EXISTS canonical_products_unbranded_key;
DROP INDEX IF EXISTS canonical_products_branded_key;

ALTER TABLE canonical_products
  ADD COLUMN name text,
  ADD COLUMN unit product_unit,
  ADD COLUMN category_id uuid REFERENCES categories (id) ON DELETE RESTRICT,
  ADD COLUMN substitute_group_id uuid;

-- Marka adı gruba geri katlanıyor. Eski şemada UNIQUE (name, size_label)
-- var; aynı grubun dört markası "Süt, tam yağlı 1 litre" olarak çakışırdı,
-- o yüzden marka adı isme giriyor. Geri alma bu yüzden kayıplı: yukarı
-- yönde tekrar çalıştırılırsa marka, grup adının parçası olarak kalır.
--
-- Marka aramasi ilişkili alt sorgu; LEFT JOIN ... ON true çapraz birleşim
-- üretiyordu ve markasız her ürün her markayla eşleşip UPDATE'i belirsiz
-- bırakıyordu.
UPDATE canonical_products cp
   SET name = trim(
         coalesce((SELECT b.name || ' ' FROM brands b WHERE b.id = cp.brand_id), '')
         || g.name
       ),
       unit = g.unit,
       category_id = g.category_id
  FROM product_groups g
 WHERE g.id = cp.group_id;

ALTER TABLE canonical_products
  ALTER COLUMN name SET NOT NULL,
  ALTER COLUMN unit SET NOT NULL,
  ALTER COLUMN category_id SET NOT NULL,
  ADD CONSTRAINT canonical_products_name_size_label_key UNIQUE (name, size_label),
  DROP COLUMN group_id,
  DROP COLUMN brand_id;

DROP TABLE IF EXISTS brands;
DROP TABLE IF EXISTS product_groups;

CREATE VIEW v_product_summary AS
SELECT o.user_id, o.canonical_product_id, cp.name, cp.size_label,
       count(*)::int AS observations,
       count(DISTINCT o.merchant_id)::int AS merchant_count,
       min(o.observed_on) AS first_seen, max(o.observed_on) AS last_seen,
       (EXTRACT(YEAR FROM age(max(o.observed_on), min(o.observed_on))) * 12
        + EXTRACT(MONTH FROM age(max(o.observed_on), min(o.observed_on))))::int AS month_span,
       (array_agg(o.pack_price ORDER BY o.observed_on ASC))[1]  AS first_pack_price,
       (array_agg(o.pack_price ORDER BY o.observed_on DESC))[1] AS last_pack_price,
       (array_agg(o.unit_price ORDER BY o.observed_on ASC))[1]  AS first_unit_price,
       (array_agg(o.unit_price ORDER BY o.observed_on DESC))[1] AS last_unit_price
  FROM price_observations o
  JOIN canonical_products cp ON cp.id = o.canonical_product_id
 WHERE NOT o.is_outlier
 GROUP BY o.user_id, o.canonical_product_id, cp.name, cp.size_label;

CREATE VIEW v_product_by_merchant AS
SELECT DISTINCT ON (o.user_id, o.canonical_product_id, o.merchant_id)
       o.user_id, o.canonical_product_id, o.merchant_id,
       m.name AS merchant_name, o.pack_price, o.unit_price, o.observed_on
  FROM price_observations o
  JOIN merchants m ON m.id = o.merchant_id
 WHERE NOT o.is_outlier
 ORDER BY o.user_id, o.canonical_product_id, o.merchant_id, o.observed_on DESC;

CREATE VIEW v_monthly_movers AS
SELECT cur.user_id, cur.month, cur.canonical_product_id, cp.name, cp.size_label,
       round((cur.unit_price / prev.unit_price - 1) * 100, 1) AS change_pct, w.weight
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
 WHERE NOT cur.is_imputed AND NOT prev.is_imputed AND prev.unit_price > 0
   AND coalesce(w.weight, 0) >= (SELECT mover_min_weight FROM index_settings WHERE id);
