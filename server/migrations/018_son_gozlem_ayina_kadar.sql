-- Up Migration

-- Endeks, hiç gözlem olmayan aya nokta koymayı bıraktı.
--
-- Aylık fiyat ızgarası her ürün için ilk gözleminden BUGÜNE kadar
-- uzatılıyordu. Amacı doğru: ocakta alınan ürünün bu ayki halkaya
-- katılabilmesi için bu ayda da bir fiyatı olmalı. Ama uzatma takvime
-- bakıyordu, veriye değil.
--
-- Sonuç: ayın başında, o ayın ilk fişi girilmeden önce, endeks o ay için de
-- bir satır yazıyordu. Bütün ürünler taşınmış fiyatla geldiği için halka tam
-- olarak 1,0 çıkıyor, seviye bir önceki ayla aynı oluyordu. Ekranda bu, en
-- sağda düz bir parça olarak görünüyor ve "bu ay değişim olmadı" diyordu —
-- oysa o ay hiç ölçülmemişti. covered_weight de 1,0 yazıyordu, yani hiç
-- gözlem olmayan bir ay için "kapsama tam" iddiası.
--
-- Vitrin hesabında ölçüldü: 2026-09'da 40 üründe 40 taşıma, 0 gözlem.
-- Diğer aylarda 40 üründe 8-13 taşıma, 43-48 gözlem — normal boşluk
-- doldurma. Ayrım keskin, arada gri bölge yok.
--
-- TAŞIMA KURALI DEĞİŞMEDİ. Gözlem olmayan aya son bilinen fiyat hâlâ
-- taşınıyor ve staleness_months hâlâ sınırlıyor; ortadaki boşluklar eskisi
-- gibi doluyor. Değişen tek şey ızgaranın nerede BİTTİĞİ: takvimin bugünü
-- yerine kullanıcının son gözlem ayı.
--
-- Ortadaki tamamen taşınmış aylar bilerek yerinde bırakıldı. Haziranda ve
-- ağustosta alışveriş yapıp temmuzu atlayan kullanıcı için temmuz "haber
-- yoksa değişim yok" demek; onu düşürmek ağustosun halkasını iki aylık bir
-- değişim hâline getirir ve tek aya yazardı.
CREATE OR REPLACE FUNCTION rebuild_monthly_prices(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_stale integer;
BEGIN
  SELECT staleness_months INTO v_stale FROM index_settings WHERE id;

  DELETE FROM monthly_product_prices WHERE user_id = p_user_id;

  INSERT INTO monthly_product_prices (
    user_id, canonical_product_id, month,
    unit_price, pack_price, observation_count, is_imputed
  )
  WITH observed AS (
    SELECT canonical_product_id,
           date_trunc('month', observed_on)::date AS month,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY unit_price) AS unit_price,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY pack_price) AS pack_price,
           count(*)::int AS observation_count
      FROM price_observations
     WHERE user_id = p_user_id AND NOT is_outlier
     GROUP BY 1, 2
  ),
  span AS (
    SELECT canonical_product_id,
           min(month) AS first_month,
           max(month) AS last_month
      FROM observed GROUP BY 1
  ),
  -- Her ürün için ilk gözleminden KULLANICININ SON GÖZLEM AYINA uzanan ay
  -- ızgarası. Ürünün ilk gözleminden ÖNCEsi doldurulmaz — geçmişe fiyat
  -- uyduramayız — ve son gözlemden SONRAsı da doldurulmaz: henüz alışveriş
  -- yapılmamış bir ay ölçülmemiş bir aydır.
  --
  -- Üst sınır global: tek tek ürünün son ayı değil, kullanıcının herhangi
  -- bir ürünü en son gördüğü ay. Ocakta alınan ürün bu ayki halkaya ancak
  -- böyle katılabiliyor. Global en büyük her zaman ürünün kendi son ayından
  -- büyük ya da ona eşit, o yüzden ayrıca greatest'e gerek yok.
  grid AS (
    SELECT sp.canonical_product_id, g.month::date AS month, sp.last_month
      FROM span sp
      CROSS JOIN LATERAL generate_series(
        sp.first_month,
        (SELECT max(month) FROM observed),
        interval '1 month'
      ) AS g (month)
  )
  SELECT p_user_id,
         grid.canonical_product_id,
         grid.month,
         carried.unit_price,
         carried.pack_price,
         coalesce(o.observation_count, 0),
         o.canonical_product_id IS NULL
    FROM grid
    LEFT JOIN observed o
      ON o.canonical_product_id = grid.canonical_product_id
     AND o.month = grid.month
    -- Son bilinen fiyatı taşı.
    CROSS JOIN LATERAL (
      SELECT ob.unit_price, ob.pack_price, ob.month AS source_month
        FROM observed ob
       WHERE ob.canonical_product_id = grid.canonical_product_id
         AND ob.month <= grid.month
       ORDER BY ob.month DESC
       LIMIT 1
    ) AS carried
   WHERE carried.source_month >= grid.month - make_interval(months => v_stale);
END;
$$;

-- Mevcut hesaplar bayat: uydurulmuş son ay hâlâ index_levels'ta duruyor.
DO $$
DECLARE u uuid;
BEGIN
  FOR u IN SELECT id FROM users LOOP
    PERFORM refresh_user_index(u);
  END LOOP;
END $$;

-- Down Migration
CREATE OR REPLACE FUNCTION rebuild_monthly_prices(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_stale integer;
BEGIN
  SELECT staleness_months INTO v_stale FROM index_settings WHERE id;

  DELETE FROM monthly_product_prices WHERE user_id = p_user_id;

  INSERT INTO monthly_product_prices (
    user_id, canonical_product_id, month,
    unit_price, pack_price, observation_count, is_imputed
  )
  WITH observed AS (
    SELECT canonical_product_id,
           date_trunc('month', observed_on)::date AS month,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY unit_price) AS unit_price,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY pack_price) AS pack_price,
           count(*)::int AS observation_count
      FROM price_observations
     WHERE user_id = p_user_id AND NOT is_outlier
     GROUP BY 1, 2
  ),
  span AS (
    SELECT canonical_product_id,
           min(month) AS first_month,
           max(month) AS last_month
      FROM observed GROUP BY 1
  ),
  grid AS (
    SELECT sp.canonical_product_id, g.month::date AS month, sp.last_month
      FROM span sp
      CROSS JOIN LATERAL generate_series(
        sp.first_month,
        greatest(sp.last_month, date_trunc('month', current_date)::date),
        interval '1 month'
      ) AS g (month)
  )
  SELECT p_user_id,
         grid.canonical_product_id,
         grid.month,
         carried.unit_price,
         carried.pack_price,
         coalesce(o.observation_count, 0),
         o.canonical_product_id IS NULL
    FROM grid
    LEFT JOIN observed o
      ON o.canonical_product_id = grid.canonical_product_id
     AND o.month = grid.month
    CROSS JOIN LATERAL (
      SELECT ob.unit_price, ob.pack_price, ob.month AS source_month
        FROM observed ob
       WHERE ob.canonical_product_id = grid.canonical_product_id
         AND ob.month <= grid.month
       ORDER BY ob.month DESC
       LIMIT 1
    ) AS carried
   WHERE carried.source_month >= grid.month - make_interval(months => v_stale);
END;
$$;

DO $$
DECLARE u uuid;
BEGIN
  FOR u IN SELECT id FROM users LOOP
    PERFORM refresh_user_index(u);
  END LOOP;
END $$;
