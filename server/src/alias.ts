/**
 * Öğrenilmiş eşleşmeler: "şu markette şu ham metin, şu üründür".
 *
 * Bu bilgi bir kullanıcının cevabından doğuyor ama HERKESİ ilgilendiriyor —
 * "MIGROS T.YAGLI YOGU." satırı kim tararsa tarasın aynı ürün. Paylaşmak
 * doğru; ama tek bir cevabın herkesin gerçeği olması değil.
 *
 * Yanlış bir alias sessizce yanlış enflasyon üretiyor: yanlış ürün, yanlış
 * birim fiyat, yanlış endeks. Kullanıcı bunu ekranda göremez bile, çünkü
 * satır "eşleşmiş" görünür.
 *
 * İKİ KATMAN:
 *
 *   Kendi oyun    fişin sahibi sensin, paketi sen gördün. Kendi fişinde
 *                 senin cevabın her zaman kazanıyor.
 *   Mutabakat     başkalarının satırlarında kullanılan cevap. En az iki
 *                 kullanıcının katılması ve ikincisinden kesin fazla olması
 *                 gerekiyor.
 */
import type { PoolClient } from 'pg';

/**
 * Mutabakat için gereken en az oy.
 *
 * İki: tek kişinin cevabı yayılmıyor, iki kişi aynı şeyi diyorsa yayılıyor.
 *
 * Bugün uygulamanın tek gerçek kullanıcısı var, yani mutabakat pratikte hiç
 * oluşmayacak — ve bu bir kayıp değil: herkes kendi cevabını zaten alıyor.
 * Eşiğin değeri tam da kullanıcı sayısı arttığında, yani zehirlenmenin
 * mümkün olduğu anda ortaya çıkıyor. Kendi kendini ölçekliyor.
 */
export const MUTABAKAT_ESIGI = 2;

type Calistir = <T extends Record<string, unknown>>(
  sql: string,
  params: unknown[],
) => Promise<T[]>;

function calistirici(client: PoolClient): Calistir {
  return async <T extends Record<string, unknown>>(
    sql: string,
    params: unknown[],
  ) => (await client.query(sql, params)).rows as T[];
}

/**
 * Bu ham metnin bu kullanıcı için karşılığı.
 *
 * Önce kendi oyu, sonra mutabakat. Sıra kasıtlı: mutabakat çoğunluğun
 * bildiği, kendi oyu ise senin gördüğün. Kendi fişinde seninki kazanıyor.
 */
export async function aliasCoz(
  client: PoolClient,
  opts: { merchantId: string; raw: string; userId: string },
): Promise<{ canonicalProductId: string; kendi: boolean } | null> {
  const calistir = calistirici(client);
  const rows = await calistir<{
    canonical_product_id: string | null;
    kendi: boolean;
  }>(
    `SELECT coalesce(v.canonical_product_id, a.canonical_product_id)
              AS canonical_product_id,
            v.canonical_product_id IS NOT NULL AS kendi
       FROM (SELECT normalize_raw_text($2) AS n) k
       LEFT JOIN alias_votes v
              ON v.merchant_id = $1 AND v.raw_text_normalized = k.n
             AND v.user_id = $3
       LEFT JOIN product_aliases a
              ON a.merchant_id = $1 AND a.raw_text_normalized = k.n`,
    [opts.merchantId, opts.raw, opts.userId],
  );

  const r = rows[0];
  if (!r?.canonical_product_id) return null;
  return { canonicalProductId: r.canonical_product_id, kendi: r.kendi };
}

/**
 * Kullanıcının cevabını oy olarak yazar ve mutabakatı yeniden hesaplar.
 *
 * Mutabakat kaybolduysa paylaşılan alias SİLİNİYOR. Bu kasıtlı: iki kişi
 * birer oyla anlaşamıyorsa, ortada herkese dayatılacak bir doğru yok ve
 * doğru davranış üçüncü kişiye sormak. Eskiden son cevap sessizce kazanıyordu.
 */
export async function aliasOyVer(
  client: PoolClient,
  opts: {
    merchantId: string;
    raw: string;
    userId: string;
    canonicalProductId: string;
  },
): Promise<void> {
  const calistir = calistirici(client);

  await calistir(
    `INSERT INTO alias_votes
       (merchant_id, raw_text_normalized, canonical_product_id, user_id)
     VALUES ($1, normalize_raw_text($2), $3, $4)
     ON CONFLICT (merchant_id, raw_text_normalized, user_id)
     DO UPDATE SET canonical_product_id = EXCLUDED.canonical_product_id,
                   created_at = now()`,
    [opts.merchantId, opts.raw, opts.canonicalProductId, opts.userId],
  );

  // Kazanan: en çok oyu alan ürün. Beraberlik kazanan sayılmıyor — iki ürün
  // aynı oydaysa hangisinin doğru olduğunu bilmiyoruz demektir.
  const sayim = await calistir<{ canonical_product_id: string; oy: string }>(
    `SELECT canonical_product_id, count(*)::text AS oy
       FROM alias_votes
      WHERE merchant_id = $1 AND raw_text_normalized = normalize_raw_text($2)
      GROUP BY canonical_product_id
      ORDER BY count(*) DESC`,
    [opts.merchantId, opts.raw],
  );

  const birinci = sayim[0];
  const ikinci = sayim[1];
  const kazandi =
    birinci !== undefined &&
    Number(birinci.oy) >= MUTABAKAT_ESIGI &&
    (ikinci === undefined || Number(birinci.oy) > Number(ikinci.oy));

  if (kazandi) {
    await calistir(
      `INSERT INTO product_aliases
         (merchant_id, raw_text_normalized, canonical_product_id, confirmations)
       VALUES ($1, normalize_raw_text($2), $3, $4)
       ON CONFLICT (merchant_id, raw_text_normalized)
       DO UPDATE SET canonical_product_id = EXCLUDED.canonical_product_id,
                     confirmations = EXCLUDED.confirmations`,
      [
        opts.merchantId,
        opts.raw,
        birinci.canonical_product_id,
        Number(birinci.oy),
      ],
    );
    return;
  }

  // Mutabakat yok. Tohumdan gelen eski bir satır varsa o da düşüyor:
  // gerçek bir kullanıcının oyu, sahibi belli olmayan tohum verisinden
  // daha iyi kanıt ve o ham metin artık tartışmalı.
  await calistir(
    `DELETE FROM product_aliases
      WHERE merchant_id = $1 AND raw_text_normalized = normalize_raw_text($2)`,
    [opts.merchantId, opts.raw],
  );
}
