-- Up Migration

-- Yapışık yazılmış fiş satırları.
--
-- A101 ve e-arşiv yazıcıları ürün adını boşluksuz ve kesik basıyor:
--
--   LOGİKAĞITHAV12Lİ   ->  Logi Kağıt Havlu 12'li
--   HIGHGENIC1L        ->  Highgenic Cam Silici 1 L
--
-- Eşleştirme belirteç bazlıydı ve belirteçler yalnızca ÖN EKTEN
-- karşılaştırılıyordu. "LOGIKAGITHAV12LI" tek bir belirteç ve hiçbir
-- katalog kelimesinin ön eki değil; sonuç sıfır aday oluyordu. Oysa aynı
-- satır boşluklu yazıldığında ("KAGIT HAVLU 12LI") 0,69 ile eşleşiyor.
-- Yani katalog eksik değildi, okuma biçimi eksikti.
--
-- Daha sinsi ikinci hâl: marka yapışık olduğunda ön ek eşleşmesi hâlâ
-- tutuyor ("PINARYOGURT1.5KG" LIKE 'PINAR%') ama grup adı hiç
-- karşılanmıyor. Puanı tek başına marka taşıyor ve ürün adı hesaba
-- girmiyor:
--
--   SUTASSUT1L  ->  Sütaş Yoğurt 1 kg   0.656   (doğrusu Sütaş Süt)
--
-- Doğru cevabı yanlıştan ayıran hiçbir sinyal kalmıyor; kalemi yanlış
-- bağlanmaktan koruyan tek şey ikinci adayın da aynı puanda olması
-- oluyor — yani marj kuralı, tesadüfen.

-- Uzun bir belirtecin İÇİNDE geçen katalog kelimesi.
--
-- Eşikler dar tutuldu: yalnızca 8 karakterden uzun belirteçlerin içinde,
-- yalnızca 4 karakterden uzun kelimeler aranıyor. Kısa kelimeleri uzun
-- metinlerde aramak ("SUT", "YAG") rastgele eşleşme üretir; yapışık yazım
-- ise doğası gereği uzun belirteç demek.
CREATE OR REPLACE FUNCTION token_glued_match(a text, b text)
RETURNS boolean LANGUAGE sql IMMUTABLE STRICT AS $fn$
  SELECT length(a) >= 8 AND length(b) >= 4 AND position(b in a) > 0
$fn$;

-- Bir kelimenin, belirtecin içinde geçen en uzun ön ekinin uzunluğu.
--
-- Yazıcı adı yalnızca yapıştırmıyor, KESİYOR da: "LOGİKAĞITHAV12Lİ"
-- içinde "HAVLU" yok ama "HAV" var. Tam kelime aranırsa kesik yazımın
-- taşıdığı bilgi tamamen çöpe gidiyor; ön ek uzunluğu ise "fişin
-- yazabildiği kadarı" demek. Üç harften kısası sayılmıyor.
CREATE OR REPLACE FUNCTION glued_prefix_len(p_token text, p_word text)
RETURNS integer LANGUAGE sql IMMUTABLE STRICT AS $fn$
  SELECT coalesce(
    (SELECT max(k)
       FROM generate_series(3, length(p_word)) k
      WHERE position(substring(p_word, 1, k) in p_token) > 0),
    0)
$fn$;

-- İki belirtecin aynı kelimeden gelip gelmediği: ön ek ya da yapışık.
--
-- Koşullar token_prefix_match / token_glued_match çağrılmak yerine ELLE
-- yazıldı. Sebebi ölçüldü: iç içe SQL fonksiyonu çağrısı satır içine
-- açılmıyor ve bu ifade katalogdaki her ürün için, her belirteç çifti
-- üzerinde çalışıyor. Çağrılı hâlinde tek satırın eşleştirilmesi 74 ms,
-- açık hâlinde 37 ms sürüyor. Tanımlar aynı — değişirlerse burası da
-- değişmeli.
CREATE OR REPLACE FUNCTION token_match(a text, b text)
RETURNS boolean LANGUAGE sql IMMUTABLE STRICT AS $fn$
  SELECT (length(a) >= 3 AND length(b) >= 3
          AND (a LIKE b || '%' OR b LIKE a || '%'))
      OR (length(a) >= 8 AND length(b) >= 4 AND position(b in a) > 0)
      OR (length(b) >= 8 AND length(a) >= 4 AND position(a in b) > 0)
$fn$;

-- Markadan SONRASI ürün adıyla başlıyor mu?
--
-- "SUTASSUT1L" içinde ürün adı "SUT" — üç harf, ve üç harfi uzun bir
-- metnin herhangi bir yerinde aramak rastgele eşleşme üretir. Ama marka
-- ("SUTAS") ön ek olarak biliniyorsa geriye kalan parça ("SUT1L")
-- doğrudan ürün adının kendisiyle başlıyor. Aranan yer belli olduğu için
-- kısa kelime burada güvenli.
--
-- Bu kural markanın açtığı deliği kapatmıyor, tersine daraltıyor:
-- "BALPARMAKPEKMEZ" için markadan sonrası "PEKMEZ" ve "BAL" ile
-- başlamıyor — yani pekmez hâlâ bal sayılmıyor.
CREATE OR REPLACE FUNCTION token_after_brand_match(
  p_raw_token text, p_brand text, p_group_token text
) RETURNS boolean LANGUAGE sql IMMUTABLE AS $fn$
  SELECT EXISTS (
    SELECT 1
      FROM unnest(to_tokens(coalesce(p_brand, ''))) bt
     WHERE length(bt) >= 3
       AND length(p_raw_token) > length(bt) + 2
       AND p_raw_token LIKE bt || '%'
       AND substring(p_raw_token from length(bt) + 1) LIKE p_group_token || '%'
  )
$fn$;

-- Bir grup kelimesinin belirteç tarafından ne kadar karşılandığı.
--
-- Kısa belirteçte ikili: ön ek eşleşmesi ya vardır ya yoktur. Uzun
-- (yapışık) belirteçte oransal — kesik yazılan kelime kısmen sayılıyor.
CREATE OR REPLACE FUNCTION group_token_cover(
  p_raw_token text, p_brand text, p_group_token text
) RETURNS numeric LANGUAGE sql IMMUTABLE AS $fn$
  -- Sıra maliyet için: ucuz ön ek testi önce, yapışık yol yalnızca uzun
  -- belirteçte. Boşluklu bir fiş satırında hiçbir belirteç 8 karakteri
  -- geçmiyor ve pahalı adımların hiçbiri çalışmıyor.
  SELECT CASE
    WHEN token_prefix_match(p_raw_token, p_group_token) THEN 1.0
    WHEN length(p_raw_token) < 8 THEN 0.0
    WHEN token_after_brand_match(p_raw_token, p_brand, p_group_token) THEN 1.0
    WHEN length(p_group_token) >= 4
      THEN least(
        1.0,
        glued_prefix_len(p_raw_token, p_group_token)::numeric
          / length(p_group_token))
    ELSE 0.0
  END
$fn$;

-- Ham metnin ürün adıyla açıklanmayan kısmı.
--
-- Yapışık belirteçte ikili (var/yok) ölçüm delik açıyordu:
-- "BALPARMAKPEKMEZ380G" belirteci markayı İÇERDİĞİ için tamamen
-- karşılanmış sayılıyor ve fişte yazan "PEKMEZ" ortadan kayboluyordu.
-- Boşluklu hâlinde 0,481 alan satır, yapışık hâlinde 0,669'a çıkıyordu —
-- yani okunması zor bir fiş, yanlış eşleşmeyi KOLAYLAŞTIRIYORDU.
--
-- Uzun belirteçlerde ölçü bu yüzden oransal: belirtecin harflerinin ne
-- kadarı ürün adının kelimeleriyle açıklanıyor.
CREATE OR REPLACE FUNCTION raw_coverage(p_raw text, p_product text)
RETURNS numeric LANGUAGE sql IMMUTABLE STRICT AS $fn$
  WITH kelime AS (
    SELECT rt FROM unnest(to_tokens(p_raw)) rt
     WHERE length(rt) >= 3
       AND rt !~ '^[0-9]'
       AND rt NOT IN ('ADET','PAKET','KUTU','LITRE','GRAM','SISE','TENEKE')
  )
  SELECT coalesce(
           avg(
             CASE
               WHEN length(rt) < 8 THEN
                 CASE WHEN EXISTS (
                   SELECT 1 FROM unnest(to_tokens(p_product)) pt
                    WHERE token_match(rt, pt)
                 ) THEN 1.0 ELSE 0.0 END
               ELSE least(
                 1.0,
                 (
                   SELECT coalesce(sum(glued_prefix_len(rt, pt)), 0)::numeric
                     FROM (
                       SELECT DISTINCT pt
                         FROM unnest(to_tokens(p_product)) pt
                        WHERE length(pt) >= 4
                     ) kelimeler
                 ) / greatest(
                       length(regexp_replace(rt, '[^A-ZÇĞİÖŞÜ]', '', 'g')),
                       1)
               )
             END),
           1.0)::numeric
    FROM kelime
$fn$;

CREATE OR REPLACE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $fn$
  WITH raw AS (
    SELECT to_tokens(p_raw) AS toks,
           normalize_raw_text(p_raw) AS flat,
           -- Satırda yapışık yazım var mı? Yoksa pahalı yolların hiçbiri
           -- çalışmıyor ve maliyet eski hâline dönüyor.
           EXISTS (
             SELECT 1 FROM unnest(to_tokens(p_raw)) t WHERE length(t) >= 8
           ) AS yapisik
  ),
  scored AS (
    SELECT
      v.id,
      CASE
        WHEN v.brand_name IS NULL THEN NULL
        WHEN EXISTS (
          SELECT 1
            FROM unnest(to_tokens(v.brand_name)) bt,
                 unnest(r.toks) rt
           WHERE token_match(rt, bt)
        ) THEN 1.0
        ELSE 0.0
      END AS brand_hit,
      (
        SELECT coalesce(avg(
          CASE
            -- Ucuz yol, eskisiyle birebir aynı: ön ek eşleşmesi bulunan
            -- ilk belirteçte duruyor. Boşluklu bir satırda hesap burada
            -- bitiyor ve yapışık mantığın maliyeti hiç doğmuyor.
            WHEN EXISTS (
              SELECT 1 FROM unnest(r.toks) rt
               WHERE token_prefix_match(rt, gt)
                 -- Markanın karşıladığı belirteç grubu da karşılamış
                 -- sayılmıyor; aksi hâlde marka iki kez puanlanıyor
                 -- ("BALPARMAK PEKMEZ" -> "Balparmak Bal").
                 AND NOT EXISTS (
                       SELECT 1
                         FROM unnest(
                           to_tokens(coalesce(v.brand_name, ''))) bt2
                        WHERE token_prefix_match(rt, bt2)
                     )
            ) THEN 1.0
            WHEN NOT r.yapisik THEN 0.0
            -- Yapışık satırda oransal: kesik yazılan kelime kısmen
            -- sayılıyor, marka vetosu ise gevşiyor — "PINARYOGURT" hem
            -- markayı hem grubu İÇERİYOR ve ikisi ayrı kelimeler.
            ELSE (
              SELECT coalesce(max(
                CASE
                  -- Marka vetosu burada da geçerli — yalnızca yapışık
                  -- kanıt varken gevşiyor: "PINARYOGURT" grubu markadan
                  -- BAĞIMSIZ olarak içeriyor, "BALPARMAK" ise "BAL"ı
                  -- yalnızca markanın kendisi olduğu için taşıyor.
                  WHEN EXISTS (
                    SELECT 1
                      FROM unnest(
                        to_tokens(coalesce(v.brand_name, ''))) bt2
                     WHERE token_prefix_match(rt, bt2)
                  )
                   AND NOT token_glued_match(rt, gt)
                   AND NOT token_after_brand_match(rt, v.brand_name, gt)
                    THEN 0.0
                  ELSE group_token_cover(rt, v.brand_name, gt)
                END), 0.0)
                FROM unnest(r.toks) rt
            )
          END), 0.0)
          FROM unnest(to_tokens(v.group_name)) gt
      ) AS group_cov,
      raw_coverage(p_raw, coalesce(v.brand_name, '') || ' ' || v.group_name)
        AS raw_cov,
      similarity(r.flat, normalize_raw_text(v.display_name)) AS trgm
      FROM v_canonical_products v, raw r
  )
  SELECT id,
         round(
           CASE
             WHEN brand_hit IS NULL
               THEN 0.40 * group_cov + 0.44 * raw_cov + 0.16 * trgm
             ELSE 0.25 * brand_hit + 0.25 * group_cov
                  + 0.38 * raw_cov + 0.12 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25 OR brand_hit = 1.0
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$fn$;

-- Down Migration

-- Önce catalog_match ve raw_coverage eski hâllerine dönüyor: yeni
-- fonksiyonlar onların İÇİNDEN çağrılıyor, önce düşürülürse sorgu kırılır.
CREATE OR REPLACE FUNCTION raw_coverage(p_raw text, p_product text)
RETURNS numeric LANGUAGE sql IMMUTABLE STRICT AS $fn$
  WITH kelime AS (
    SELECT rt FROM unnest(to_tokens(p_raw)) rt
     WHERE length(rt) >= 3
       AND rt !~ '^[0-9]'
       AND rt NOT IN ('ADET','PAKET','KUTU','LITRE','GRAM','SISE','TENEKE')
  )
  SELECT coalesce(
           avg(CASE WHEN EXISTS (
                 SELECT 1 FROM unnest(to_tokens(p_product)) pt
                  WHERE token_prefix_match(rt, pt)
               ) THEN 1.0 ELSE 0.0 END),
           1.0)::numeric
    FROM kelime
$fn$;

CREATE OR REPLACE FUNCTION catalog_match(p_raw text, p_limit integer DEFAULT 5)
RETURNS TABLE (canonical_product_id uuid, score numeric)
LANGUAGE sql STABLE AS $fn$
  WITH raw AS (
    SELECT to_tokens(p_raw) AS toks, normalize_raw_text(p_raw) AS flat
  ),
  scored AS (
    SELECT
      v.id,
      CASE
        WHEN v.brand_name IS NULL THEN NULL
        WHEN EXISTS (
          SELECT 1
            FROM unnest(to_tokens(v.brand_name)) bt,
                 unnest(r.toks) rt
           WHERE token_prefix_match(rt, bt)
        ) THEN 1.0
        ELSE 0.0
      END AS brand_hit,
      (
        SELECT coalesce(
                 avg(CASE WHEN EXISTS (
                       SELECT 1 FROM unnest(r.toks) rt
                        WHERE token_prefix_match(rt, gt)
                          AND NOT EXISTS (
                                SELECT 1
                                  FROM unnest(
                                    to_tokens(coalesce(v.brand_name, ''))) bt2
                                 WHERE token_prefix_match(rt, bt2)
                              )
                     ) THEN 1.0 ELSE 0.0 END),
                 0.0)
          FROM unnest(to_tokens(v.group_name)) gt
      ) AS group_cov,
      raw_coverage(p_raw, coalesce(v.brand_name, '') || ' ' || v.group_name)
        AS raw_cov,
      similarity(r.flat, normalize_raw_text(v.display_name)) AS trgm
      FROM v_canonical_products v, raw r
  )
  SELECT id,
         round(
           CASE
             WHEN brand_hit IS NULL
               THEN 0.40 * group_cov + 0.44 * raw_cov + 0.16 * trgm
             ELSE 0.25 * brand_hit + 0.25 * group_cov
                  + 0.38 * raw_cov + 0.12 * trgm
           END::numeric,
           3)
    FROM scored
   WHERE group_cov > 0 OR trgm > 0.25 OR brand_hit = 1.0
   ORDER BY 2 DESC, 1
   LIMIT p_limit
$fn$;

DROP FUNCTION IF EXISTS group_token_cover(text, text, text);
DROP FUNCTION IF EXISTS glued_prefix_len(text, text);
DROP FUNCTION IF EXISTS token_after_brand_match(text, text, text);
DROP FUNCTION IF EXISTS token_match(text, text);
DROP FUNCTION IF EXISTS token_glued_match(text, text);
