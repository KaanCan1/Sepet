-- Up Migration

CREATE TABLE users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       text,
  name        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

-- citext eklentisi yerine lower() üzerinde tekil indeks: bağımlılık eklemeden
-- büyük/küçük harf duyarsız benzersizlik.
CREATE UNIQUE INDEX users_email_key ON users (lower(email)) WHERE email IS NOT NULL;

CREATE TYPE auth_provider AS ENUM ('apple', 'google', 'email');

-- Karşılama ekranındaki üç sağlayıcının karşılığı. Apple'ın gizli yönlendirme
-- adresi burada durur, kanonik e-posta users'ta.
CREATE TABLE auth_identities (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  provider          auth_provider NOT NULL,
  provider_user_id  text NOT NULL,
  email_at_provider text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_user_id)
);

CREATE INDEX auth_identities_user_idx ON auth_identities (user_id);

CREATE TYPE receipt_source AS ENUM ('ocr', 'manual');

-- Fişin kendisi.
--
-- KVKK — veri minimizasyonu: fişin tam OCR metni SAKLANMIYOR. Hesap için
-- gereken tek şey eşleşmiş satırlar; ham metin fazladan kişisel veridir.
CREATE TABLE receipts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  merchant_id   uuid NOT NULL REFERENCES merchants (id) ON DELETE RESTRICT,
  purchased_at  date NOT NULL,
  total_amount  numeric(12, 2) NOT NULL CHECK (total_amount >= 0),
  currency      char(3) NOT NULL DEFAULT 'TRY',
  source        receipt_source NOT NULL DEFAULT 'ocr',
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX receipts_user_date_idx ON receipts (user_id, purchased_at DESC);

CREATE TYPE match_status AS ENUM ('pending', 'auto', 'confirmed', 'rejected');

-- HAM katman: OCR'ın ne dediği. Eşleşme beklerken de burada durur.
CREATE TABLE receipt_lines (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id           uuid NOT NULL REFERENCES receipts (id) ON DELETE CASCADE,
  line_no              integer NOT NULL,
  raw_text             text NOT NULL,          -- "AYCICEK YAGI 5L"
  quantity             numeric(12, 4) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  line_amount          numeric(12, 2) NOT NULL CHECK (line_amount >= 0),
  canonical_product_id uuid REFERENCES canonical_products (id) ON DELETE SET NULL,
  status               match_status NOT NULL DEFAULT 'pending',
  match_confidence     numeric(4, 3) CHECK (match_confidence BETWEEN 0 AND 1),
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (receipt_id, line_no),
  -- Eşleşmiş sayılan satırın ürünü olmak zorunda.
  CONSTRAINT matched_line_has_product
    CHECK (status NOT IN ('auto', 'confirmed') OR canonical_product_id IS NOT NULL)
);

CREATE INDEX receipt_lines_receipt_idx ON receipt_lines (receipt_id);
CREATE INDEX receipt_lines_pending_idx ON receipt_lines (receipt_id)
  WHERE status = 'pending';

-- Down Migration
DROP TABLE IF EXISTS receipt_lines;
DROP TYPE IF EXISTS match_status;
DROP TABLE IF EXISTS receipts;
DROP TYPE IF EXISTS receipt_source;
DROP TABLE IF EXISTS auth_identities;
DROP TYPE IF EXISTS auth_provider;
DROP TABLE IF EXISTS users;
