-- Up Migration

-- ── Aşama 1: aykırı işaretleme ──────────────────────────────────────────────
-- OCR'ın virgül kaydırması (389,90 -> 38990) endeksi sessizce bozar. Her
-- gözlem, aynı üründeki DİĞER gözlemlerin medyanına oranlanır; oran sınırların
-- dışındaysa elenir.
--
-- Kendi kendini medyana katmamak önemli: iki gözlemden biri bozuksa medyan
-- ikisinin ortasına düşer ve ikisi de "normal" görünebilir.
CREATE FUNCTION flag_outliers(p_user_id uuid) RETURNS void
LANGUAGE sql AS $$
  WITH s AS (SELECT * FROM index_settings WHERE id),
  peer_median AS (
    SELECT o.id,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY p.unit_price) AS med
      FROM price_observations o
      JOIN price_observations p
        ON p.user_id = o.user_id
       AND p.canonical_product_id = o.canonical_product_id
       AND p.id <> o.id
     WHERE o.user_id = p_user_id
     GROUP BY o.id
  )
  UPDATE price_observations o
     SET is_outlier = (
           pm.med IS NOT NULL
           AND (o.unit_price < pm.med * s.outlier_low_ratio
             OR o.unit_price > pm.med * s.outlier_high_ratio)
         )
    FROM peer_median pm, s
   WHERE o.id = pm.id
     AND o.is_outlier IS DISTINCT FROM (
           pm.med IS NOT NULL
           AND (o.unit_price < pm.med * s.outlier_low_ratio
             OR o.unit_price > pm.med * s.outlier_high_ratio)
         );
$$;

-- ── Aşama 2: aylık fiyat + boşluk doldurma ──────────────────────────────────
-- Gözlemlerin aylık MEDYANI alınır (ortalama değil: tek bir promosyon fiyatı
-- ayı bükmesin). Gözlem olmayan aya son bilinen fiyat taşınır — "haber yoksa
-- değişim yok". Taşıma staleness_months'u geçerse satır üretilmez: bilmediğimiz
-- fiyatı biliyormuş gibi yapmıyoruz.
CREATE FUNCTION rebuild_monthly_prices(p_user_id uuid) RETURNS void
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
  -- Her ürün için ilk gözleminden bugüne uzanan ay ızgarası. Ürünün ilk
  -- gözleminden ÖNCEsi doldurulmaz — geçmişe fiyat uyduramayız.
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

-- ── Aşama 3: ağırlıklar ─────────────────────────────────────────────────────
-- Harcama payı: bir ürüne verilen para / toplam harcama. Pencere, hesaplanan
-- aydan GERİYE bakar ve cari ayı DIŞARIDA bırakır — yoksa bu ay çok aldığın
-- şey kendi ağırlığını şişirir.
CREATE FUNCTION rebuild_weights(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_window integer;
BEGIN
  SELECT weight_window_months INTO v_window FROM index_settings WHERE id;

  DELETE FROM basket_weights WHERE user_id = p_user_id;

  INSERT INTO basket_weights (user_id, canonical_product_id, as_of_month, weight, expenditure)
  WITH months AS (
    SELECT DISTINCT month FROM monthly_product_prices WHERE user_id = p_user_id
  ),
  spend AS (
    SELECT m.month AS as_of_month,
           o.canonical_product_id,
           sum(o.amount) AS expenditure
      FROM months m
      JOIN price_observations o
        ON o.user_id = p_user_id
       AND NOT o.is_outlier
       AND o.observed_on >= m.month - make_interval(months => v_window)
       AND o.observed_on <  m.month
     GROUP BY 1, 2
  )
  SELECT p_user_id,
         canonical_product_id,
         as_of_month,
         expenditure / sum(expenditure) OVER (PARTITION BY as_of_month),
         expenditure
    FROM spend
   WHERE expenditure > 0;
END;
$$;

-- ── Aşama 4: zincirleme ─────────────────────────────────────────────────────
-- Aylık halka:  L_t = Σ_{i∈M_t} w_i,t * (p_i,t / p_i,t-1)
--   M_t = t ve t-1'in İKİSİNDE de fiyatı olan ürünler
--   w   = M_t üzerinde yeniden normalize edilmiş ağırlık
--
-- Seviye kümülatif çarpım: I_t = I_{t-1} * L_t, ilk ay 100.
-- Postgres'te kümülatif çarpım penceresi yok; exp(Σ ln) ile alınıyor.
--
-- Sabit bazlı Laspeyres yerine zincirleme kullanılmasının sebebi sepet kayması:
-- yeni almaya başladığın ürünün baz dönemde fiyatı yok. Zincirleme sepetin
-- evrilmesine izin verir.
CREATE FUNCTION rebuild_index_levels(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM index_levels WHERE user_id = p_user_id;

  INSERT INTO index_levels (user_id, month, link, level, covered_weight)
  WITH paired AS (
    SELECT cur.month,
           cur.canonical_product_id,
           cur.unit_price / prev.unit_price AS relative,
           coalesce(w.weight, 0) AS weight
      FROM monthly_product_prices cur
      JOIN monthly_product_prices prev
        ON prev.user_id = cur.user_id
       AND prev.canonical_product_id = cur.canonical_product_id
       AND prev.month = cur.month - interval '1 month'
      LEFT JOIN basket_weights w
        ON w.user_id = cur.user_id
       AND w.canonical_product_id = cur.canonical_product_id
       AND w.as_of_month = cur.month
     WHERE cur.user_id = p_user_id
       AND prev.unit_price > 0
  ),
  links AS (
    SELECT month,
           sum(weight) AS covered_weight,
           CASE WHEN sum(weight) > 0
                THEN sum(weight * relative) / sum(weight)
                ELSE 1
           END AS link
      FROM paired
     GROUP BY month
  ),
  -- Serinin başı: ilk fiyat ayı, halkası 1, seviyesi 100.
  first_month AS (
    SELECT min(month) AS month FROM monthly_product_prices WHERE user_id = p_user_id
  ),
  series AS (
    SELECT month, 1::numeric AS link, 0::numeric AS covered_weight FROM first_month
     WHERE month IS NOT NULL
    UNION ALL
    SELECT month, link, covered_weight FROM links
  )
  SELECT p_user_id,
         month,
         link,
         100 * exp(sum(ln(link)) OVER (ORDER BY month)),
         covered_weight
    FROM series;
END;
$$;

-- Hepsini sırayla çalıştırır. Fiş eklendiğinde ya da bir eşleşme
-- düzeltildiğinde çağrılır.
CREATE FUNCTION refresh_user_index(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM flag_outliers(p_user_id);
  PERFORM rebuild_monthly_prices(p_user_id);
  PERFORM rebuild_weights(p_user_id);
  PERFORM rebuild_index_levels(p_user_id);
END;
$$;

-- Down Migration
DROP FUNCTION IF EXISTS refresh_user_index (uuid);
DROP FUNCTION IF EXISTS rebuild_index_levels (uuid);
DROP FUNCTION IF EXISTS rebuild_weights (uuid);
DROP FUNCTION IF EXISTS rebuild_monthly_prices (uuid);
DROP FUNCTION IF EXISTS flag_outliers (uuid);
