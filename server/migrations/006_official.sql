-- Up Migration

CREATE TABLE official_series (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code       text NOT NULL UNIQUE,     -- TUIK_TUFE, ENAG_ETUFE
  publisher  text NOT NULL,
  name       text NOT NULL,
  -- Resmî kurum mu, bağımsız ölçüm mü. Ekranda etiket olarak görünüyor.
  is_official boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE official_index_levels (
  series_id    uuid NOT NULL REFERENCES official_series (id) ON DELETE CASCADE,
  month        date NOT NULL,
  level        numeric(14, 6),
  -- Kaynak yıllık değişimi kendisi açıklıyorsa onu kullan; seviyeden yeniden
  -- hesaplamak yuvarlama farkı üretir.
  yoy_pct      numeric(8, 3),
  published_at date,
  PRIMARY KEY (series_id, month)
);

-- Down Migration
DROP TABLE IF EXISTS official_index_levels;
DROP TABLE IF EXISTS official_series;
