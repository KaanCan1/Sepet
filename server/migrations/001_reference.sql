-- Up Migration

-- Sınıflandırma. COICOP benzeri ağaç; TÜİK alt endeksleriyle eşleştirebilmek
-- için kod alanı var.
CREATE TABLE categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE,
  name        text NOT NULL,
  parent_id   uuid REFERENCES categories (id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE merchants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  chain_code  text NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Fiyatın ölçüldüğü kanonik birim. Endeks paket fiyatını değil birim fiyatı
-- karşılaştırır; yoksa 1 L yerine 2 L alan kullanıcıda sahte enflasyon çıkar.
CREATE TYPE product_unit AS ENUM ('litre', 'kilogram', 'adet');

-- Endeksin atomu.
CREATE TABLE canonical_products (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,                 -- "Ayçiçek yağı"
  size_label   text NOT NULL,                 -- "5 litre"
  unit         product_unit NOT NULL,
  -- Paket içeriği kanonik birim cinsinden: 5 L yağ -> 5, 30'lu yumurta -> 30.
  size_value   numeric(12, 4) NOT NULL CHECK (size_value > 0),
  category_id  uuid NOT NULL REFERENCES categories (id) ON DELETE RESTRICT,
  -- Paket değişimini (30'lu -> 15'li) ileride birim fiyat üzerinden
  -- zincirleyebilmek için. v1'de kullanılmıyor.
  substitute_group_id uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (name, size_label)
);

CREATE INDEX canonical_products_category_idx ON canonical_products (category_id);
CREATE INDEX canonical_products_substitute_idx ON canonical_products (substitute_group_id)
  WHERE substitute_group_id IS NOT NULL;

-- Ham fiş metninin hangi kanonik ürüne gittiğini tutan önbellek.
-- "eşleşme?" sorusu cevaplandıkça büyür; ikinci kez aynı metin geldiğinde
-- modele hiç gidilmez.
--
-- Market bazlı: aynı ham metin farklı zincirde farklı ürün olabilir.
CREATE TABLE product_aliases (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id          uuid NOT NULL REFERENCES merchants (id) ON DELETE CASCADE,
  raw_text_normalized  text NOT NULL,
  canonical_product_id uuid NOT NULL REFERENCES canonical_products (id) ON DELETE CASCADE,
  confirmations        integer NOT NULL DEFAULT 1 CHECK (confirmations > 0),
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, raw_text_normalized)
);

-- Ham fiş metnini eşleştirmeye uygun hâle getirir: büyük harf (Türkçe'ye
-- duyarlı), fazla boşluk atılmış, noktalama sadeleştirilmiş.
CREATE FUNCTION normalize_raw_text(p_text text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT AS $$
  SELECT regexp_replace(
           upper(translate(p_text, 'ıİğĞüÜşŞöÖçÇ', 'IIGGUUSSOOCC')),
           '[^A-Z0-9]+', ' ', 'g'
         )
$$;

-- Down Migration
DROP FUNCTION IF EXISTS normalize_raw_text (text);
DROP TABLE IF EXISTS product_aliases;
DROP TABLE IF EXISTS canonical_products;
DROP TYPE IF EXISTS product_unit;
DROP TABLE IF EXISTS merchants;
DROP TABLE IF EXISTS categories;
