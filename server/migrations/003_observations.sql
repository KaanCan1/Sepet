-- Up Migration

-- TEMİZ katman: hesaba girmeye uygun olan. Yalnızca eşleşmiş satırlar düşer.
--
-- receipt_lines'tan ayrı olması bilinçli: bir eşleşme sonradan düzeltilirse
-- ham katman değişmeden türev katman yeniden üretilir.
CREATE TABLE price_observations (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  receipt_line_id      uuid NOT NULL UNIQUE REFERENCES receipt_lines (id) ON DELETE CASCADE,
  canonical_product_id uuid NOT NULL REFERENCES canonical_products (id) ON DELETE CASCADE,
  merchant_id          uuid NOT NULL REFERENCES merchants (id) ON DELETE RESTRICT,
  observed_on          date NOT NULL,
  -- Endeksin kullandığı: kanonik birim başına fiyat (TL/litre, TL/kg, TL/adet).
  unit_price           numeric(14, 6) NOT NULL CHECK (unit_price > 0),
  -- Ekranda gösterilen: bir paketin fiyatı. Ekran 03 "İlk gördüğün 248,00"
  -- derken bunu kullanıyor.
  pack_price           numeric(12, 2) NOT NULL CHECK (pack_price > 0),
  -- Ağırlık hesabının girdisi: bu satıra fiilen ödenen tutar.
  amount               numeric(12, 2) NOT NULL CHECK (amount >= 0),
  is_outlier           boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX price_observations_user_product_date_idx
  ON price_observations (user_id, canonical_product_id, observed_on);
CREATE INDEX price_observations_user_date_idx
  ON price_observations (user_id, observed_on)
  WHERE NOT is_outlier;

-- Fiş satırından birim fiyatı türetir.
--
--   unit_price = line_amount / (quantity * size_value)
--
-- "SUT TAM YAGLI 1L" x3 -> 116,70 / (3 * 1)     = 38,90 TL/L
-- "DOMATES KG 1,240"    ->  92,88 / (1,240 * 1) = 74,90 TL/kg
-- "YUMURTA 30LU"        -> 184,50 / (1 * 30)    =  6,15 TL/adet
--
-- Yumurta satırı "eşleşme?" etiketinin neden kritik olduğunu gösteriyor:
-- 30'lu mu 15'li mi sorusunun cevabı size_value'yu, o da birim fiyatı belirler.
CREATE FUNCTION sync_price_observation() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_user_id     uuid;
  v_merchant_id uuid;
  v_date        date;
  v_size        numeric;
BEGIN
  -- Eşleşmemiş ya da reddedilmiş satır hesaba girmez.
  IF NEW.status NOT IN ('auto', 'confirmed') OR NEW.canonical_product_id IS NULL THEN
    DELETE FROM price_observations WHERE receipt_line_id = NEW.id;
    RETURN NEW;
  END IF;

  SELECT r.user_id, r.merchant_id, r.purchased_at
    INTO v_user_id, v_merchant_id, v_date
    FROM receipts r WHERE r.id = NEW.receipt_id;

  SELECT cp.size_value INTO v_size
    FROM canonical_products cp WHERE cp.id = NEW.canonical_product_id;

  -- Bedava kalem (0 TL) fiyat gözlemi değil; endeksi sıfıra çeker.
  IF NEW.line_amount <= 0 THEN
    DELETE FROM price_observations WHERE receipt_line_id = NEW.id;
    RETURN NEW;
  END IF;

  INSERT INTO price_observations (
    user_id, receipt_line_id, canonical_product_id, merchant_id,
    observed_on, unit_price, pack_price, amount
  )
  VALUES (
    v_user_id, NEW.id, NEW.canonical_product_id, v_merchant_id,
    v_date,
    NEW.line_amount / (NEW.quantity * v_size),
    NEW.line_amount / NEW.quantity,
    NEW.line_amount
  )
  ON CONFLICT (receipt_line_id) DO UPDATE SET
    canonical_product_id = EXCLUDED.canonical_product_id,
    merchant_id          = EXCLUDED.merchant_id,
    observed_on          = EXCLUDED.observed_on,
    unit_price           = EXCLUDED.unit_price,
    pack_price           = EXCLUDED.pack_price,
    amount               = EXCLUDED.amount;

  RETURN NEW;
END;
$$;

CREATE TRIGGER receipt_lines_sync_observation
  AFTER INSERT OR UPDATE OF status, canonical_product_id, quantity, line_amount
  ON receipt_lines
  FOR EACH ROW EXECUTE FUNCTION sync_price_observation();

-- Down Migration
DROP TRIGGER IF EXISTS receipt_lines_sync_observation ON receipt_lines;
DROP FUNCTION IF EXISTS sync_price_observation ();
DROP TABLE IF EXISTS price_observations;
