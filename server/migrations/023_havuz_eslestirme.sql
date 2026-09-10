-- Up Migration

-- Fiş satırını havuzdaki ürünle eşleştirir.
--
-- catalog_match sepete bakıyor ve puanı MARKA + GRUP olarak iki parçadan
-- kuruyor, çünkü sepetteki kalemin adı yok — "Sütaş" + "Yoğurt" + "1 kg"
-- üçlüsü var. Havuzdaki kalemin ise tek bir BAŞLIĞI var: "Sütaş Kaymaklı
-- Yoğurt 1 Kg". Puan bu yüzden başka türlü kuruluyor; ikisi ayrı fonksiyon.
--
-- Ama İLKELER ORTAK: to_tokens, token_match. İkinci bir eşleştirme motoru
-- yazmıyoruz — aynı taşlarla başka bir duvar örüyoruz.
--
-- PUAN: fişteki belirteçlerin kaçı başlıkta karşılık buluyor.
--
--   "MIGROS T.YAGLI YOGU."         -> {MIGROS, T, YAGLI, YOGU}
--   "Migros Tam Yağlı Yoğurt 1 Kg" -> {MIGROS, TAM, YAGLI, YOGURT, 1, KG}
--
-- MIGROS tutuyor, YAGLI tutuyor, YOGU ön ek olarak YOGURT'u tutuyor.
--
-- PAYDAYA GİRMEYEN İKİ BELİRTEÇ TÜRÜ VAR ve ikisi de ölçülerek çıktı:
--
-- 1. ÜÇ HARFTEN KISALAR. "T.YAGLI"nın başındaki "T" hiçbir şeyi tutmuyor ve
--    tutmaması doğru — tek harf her şeye benzer, token_match'in üç harf
--    tabanı tam da bunun için var. Yazarkasanın kırptığı harf ürünün
--    aleyhine sayılmıyor.
--
-- 2. RAKAM İÇERENLER. "SUTAS YOGURT 1.5KG" -> {SUTAS, YOGURT, 5KG}. "5KG"
--    başlıktaki "1.5 Kg"ı belirteç olarak tutmuyor (ne "5KG" "KG"nin ön eki
--    ne tersi) ve payda üçe çıktığı için doğru kalem 0,667'ye düşüyordu —
--    yanlış kalemle AYNI puana. Oysa fişteki boy atılacak bilgi değil:
--    boyun kendi makinesi var (size-hint) ve havuzdaki kalem de boyunu
--    ayrıştırılmış olarak taşıyor. Metin eşleşmesinden çıkarılıp oraya
--    bırakılıyor.
--
-- BAŞLIĞIN ARTIĞI CEZA DEĞİL, EŞİTLİK BOZUCU. Fiş metni her zaman başlıktan
-- kısa (yazarkasa yirmi karakterde kesiyor), dolayısıyla "başlıkta
-- karşılıksız kalan belirteç" saymak her doğru eşleşmeyi cezalandırırdı.
-- Yalnızca eşit puanlı adaylar arasında kısa olan öne geçiyor.
--
-- MARKA PUANA GİRMİYOR, AYRI DÖNÜYOR. Ölçüldü: "TACIROGLI TAM YAGLI"
-- satırı — yazarkasa markayı TACIROGLU değil TACIROGLI basmış — "Eker Tam
-- Yağlı Yoğurt" ve "Torku Tam Yağlı Yoğurt" ile 0,667 alıyor. Metin puanı
-- yüksek ama markanın hiçbir kanıtı yok. Kararı veren katman brand_hit'e
-- bakıp bu satırı kullanıcıya soruyor; puanın içine gömülseydi fark
-- görünmezdi.
--
-- ÖN SÜZGEÇ. Puan her aday için başlığı yeniden belirteçlere ayırıyor ve bu
-- pahalı. Ölçüldü: 876 kalemde süzgeçsiz 71 ms, yani otuz satırlık bir fiş
-- iki saniye ederdi.
--
-- Süzgeç şu: fişteki belirteçlerden en az birinin İLK ÜÇ HARFİ başlıkta
-- geçmeli. Sağlam bir alt sınır, çünkü token_match'in ön ek dalı iki
-- belirtecin baştan en az üç harfini paylaşmasını zaten şart koşuyor —
-- tutan her aday bu süzgeçten de geçiyor. 876 aday 74'e iniyor, 71 ms 24'e.
--
-- SÜZGEÇ İNDEKSLİ DEĞİL, sıralı tarama. Denendi: pg_trgm GIN indeksi bu
-- sorguda kullanılmıyor, çünkü LIKE deseni sabit değil — her satır için
-- fişin belirteçlerinden üretiliyor ve planlayıcı değişken desene indeks
-- uygulayamıyor. Kullanılmayan indeksi bırakmak yalnızca her havuz
-- yazımını yavaşlatırdı.
--
-- Yani maliyet havuz boyuyla DOĞRU ORANTILI: satır başına ucuz bir test ama
-- her satırda. Havuz on binlere çıkınca çözüm indeks değil, veri modeli —
-- (havuz kalemi, belirteç) tablosu ve belirteç üzerinde ön ek birleşimi.
-- Bugünkü boyda gerekmiyor; gerektiğinde ölçüp yapılacak.
CREATE FUNCTION pool_match(p_raw text, p_limit int DEFAULT 5)
RETURNS TABLE (
  pool_product_id uuid,
  score numeric,
  brand_hit boolean,
  title text,
  size_value numeric,
  unit product_unit,
  canonical_product_id uuid
)
LANGUAGE sql
STABLE
AS $$
  WITH raw AS (
    SELECT array(
             SELECT t
               FROM unnest(to_tokens(p_raw)) t
              WHERE length(t) >= 3 AND t !~ '[0-9]'
           ) AS toks
  ),
  scored AS (
    SELECT p.id,
           p.title AS p_title,
           p.size_value AS p_size,
           p.unit AS p_unit,
           p.canonical_product_id AS p_canonical,
           (
             SELECT count(*)
               FROM unnest(r.toks) rt
              WHERE EXISTS (
                      SELECT 1 FROM unnest(to_tokens(p.title)) pt
                       WHERE token_match(rt, pt)
                    )
           )::numeric / array_length(r.toks, 1) AS oran,
           (
             SELECT count(*)
               FROM unnest(to_tokens(p.title)) pt
              WHERE NOT EXISTS (
                      SELECT 1 FROM unnest(r.toks) rt
                       WHERE token_match(rt, pt)
                    )
           ) AS artik,
           p.brand_text IS NOT NULL AND EXISTS (
             SELECT 1
               FROM unnest(to_tokens(p.brand_text)) bt,
                    unnest(r.toks) rt
              WHERE token_match(rt, bt)
           ) AS marka
      FROM pool_products p, raw r
     WHERE array_length(r.toks, 1) > 0
       AND EXISTS (
             SELECT 1 FROM unnest(r.toks) rt
              WHERE p.title_normalized LIKE '%' || left(rt, 3) || '%'
           )
  )
  SELECT id, oran, marka, p_title, p_size, p_unit, p_canonical
    FROM scored
   WHERE oran > 0
   ORDER BY oran DESC, marka DESC, artik ASC, id
   LIMIT p_limit
$$;

-- Down Migration

DROP FUNCTION IF EXISTS pool_match(text, int);
