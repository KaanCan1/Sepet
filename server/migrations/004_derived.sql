-- Up Migration

-- Ürün-ay bazında fiyat. Gözlem varsa medyanı, yoksa son bilinen fiyatın
-- taşınmış hâli.
CREATE TABLE monthly_product_prices (
  user_id              uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  canonical_product_id uuid NOT NULL REFERENCES canonical_products (id) ON DELETE CASCADE,
  month                date NOT NULL,
  unit_price           numeric(14, 6) NOT NULL,
  pack_price           numeric(12, 2) NOT NULL,
  observation_count    integer NOT NULL DEFAULT 0,
  -- true ise fiyat taşınmış: o ay gerçek gözlem yok.
  is_imputed           boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, canonical_product_id, month)
);

-- Sepet ağırlıkları: harcama payı.
CREATE TABLE basket_weights (
  user_id              uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  canonical_product_id uuid NOT NULL REFERENCES canonical_products (id) ON DELETE CASCADE,
  as_of_month          date NOT NULL,
  weight               numeric(10, 8) NOT NULL CHECK (weight >= 0),
  expenditure          numeric(14, 2) NOT NULL,
  PRIMARY KEY (user_id, as_of_month, canonical_product_id)
);

-- Zincirlenmiş endeks seviyesi. İlk ay 100.
CREATE TABLE index_levels (
  user_id        uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  month          date NOT NULL,
  -- Aylık halka: Σ w_i * (p_i,t / p_i,t-1). İlk ay için 1.
  link           numeric(14, 8) NOT NULL,
  level          numeric(14, 6) NOT NULL,
  -- Halkanın kapsadığı ağırlık (normalize etmeden önce). Düşükse o ayın
  -- ölçümü zayıf demektir; ekranda bunu söylemek dürüstlüğün parçası.
  covered_weight numeric(10, 8) NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, month)
);

-- Hesabın parametreleri tek yerde. Testler de bunları okur.
CREATE TABLE index_settings (
  id                     boolean PRIMARY KEY DEFAULT true CHECK (id),
  -- Son gözlemden kaç ay sonra ürün sepetten düşer.
  staleness_months       integer NOT NULL DEFAULT 6,
  -- Aykırı sınırı: gidiş medyanına oran bu aralığın dışındaysa gözlem elenir.
  outlier_low_ratio      numeric(6, 3) NOT NULL DEFAULT 0.333,
  outlier_high_ratio     numeric(6, 3) NOT NULL DEFAULT 3.0,
  -- Ağırlık penceresi (ay).
  weight_window_months   integer NOT NULL DEFAULT 12,
  -- Bu ağırlığın altındaki ürün "en çok zamlanan" listesine girmez.
  mover_min_weight       numeric(10, 8) NOT NULL DEFAULT 0.005
);

INSERT INTO index_settings (id) VALUES (true);

-- Down Migration
DROP TABLE IF EXISTS index_settings;
DROP TABLE IF EXISTS index_levels;
DROP TABLE IF EXISTS basket_weights;
DROP TABLE IF EXISTS monthly_product_prices;
