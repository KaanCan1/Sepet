-- Up Migration

-- Nitelik tek başına grup kanıtı sayılmıyor.
--
-- Ölçüldü: "TACIROGLI TAM YAGLI" satırı — gerçekte Tacıroğlu'nun bir
-- peyniri — "Tacıroğlu Süt, tam yağlı" kalemlerini 0,599 ile başa
-- koyuyordu. Sütaş'ın aynı grubu 0,460 alıyordu, yani satır ürünü değil
-- markayı doğru buluyor ama grubu tamamen ıskalıyordu.
--
-- Sebep marka DEĞİL: token_match('TACIROGLI','TACIROGLU') zaten false ve
-- brand_hit 0. Tacıroğlu'yu başa taşıyan şey raw_coverage ile trigram
-- benzerliği, ki ikisi de doğru davranıyor — marka gerçekten Tacıroğlu.
--
-- Sebep GRUP: "Süt, tam yağlı" grubu {SUT, TAM, YAGLI} belirteçlerinden
-- ikisini tutup 2/3 alıyordu. Oysa tuttuğu ikisi NİTELİK, ürünün kendisi
-- olan SÜT fişte hiç geçmiyor. "Tam yağlı" bir yağ oranı sıfatı ve peynirin,
-- yoğurdun, sütün adında birden geçiyor.
--
-- Grup adları "baş, nitelik" düzeninde ve bu yirmi beş virgüllü grubun
-- hepsinde tutuyor. Baş tutmuyorsa grup puan almıyor. Virgülsüz gruplarda
-- baş adın kendisi, yani yetmiş bir grup etkilenmiyor.
--
-- Havuz eşleştiricisi (#94) aynı tuzağa marka koşuluyla düşmüyordu; burası
-- sepet tarafındaki karşılığı.

CREATE OR REPLACE FUNCTION public.catalog_match(p_raw text, p_limit integer DEFAULT 5)
 RETURNS TABLE(canonical_product_id uuid, score numeric)
 LANGUAGE sql
 STABLE
AS $function$
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
      ) * (
        -- BAŞ KANITI ŞART.
        --
        -- Grup adları "baş, nitelik" düzeninde: "Süt, tam yağlı",
        -- "Kıyma, dana", "Ekmek, tam buğday". Yirmi beş virgüllü grubun
        -- hepsinde kural aynı. Baş ürünün KENDİSİ, nitelik onu daraltan sıfat.
        --
        -- Nitelik tek başına kanıt değil, çünkü aynı sıfat başka ürünlerin
        -- adında da geçiyor. Ölçüldü: "TACIROGLI TAM YAGLI" satırı — gerçekte
        -- bir peynir — "Süt, tam yağlı" grubundan 2/3 alıyordu. Fişte SÜT
        -- kelimesi hiç geçmiyor; puanı veren yalnızca "tam yağlı" sıfatı.
        --
        -- Ürün adının tamamı yazılmadığı için grup kapanmalı, kapanmayınca
        -- satır güvenle YANLIŞ gruba gidiyordu.
        --
        -- Virgülsüz gruplarda baş adın kendisi, yani bu kapı hep açık:
        -- doksan altı grubun yetmiş biri etkilenmiyor.
        CASE WHEN EXISTS (
               SELECT 1
                 FROM unnest(to_tokens(split_part(v.group_name, ',', 1))) ht,
                      unnest(r.toks) rt
                WHERE token_match(rt, ht)
             ) THEN 1.0 ELSE 0.0 END
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
$function$;


-- Down Migration

-- Kapı kaldırılıyor: nitelik yine tek başına grup kanıtı sayılır.
