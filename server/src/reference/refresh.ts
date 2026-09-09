/**
 * Referans fiyatların günlük anlık görüntüsü.
 *
 * Kaynak yalnızca BUGÜNKÜ fiyatı yayımlıyor; geçmiş sorulamıyor. Bunun tek
 * bir sonucu var: toplanmayan günün verisi kalıcı olarak kayıp. Bu yüzden
 * çekim günlük ve bu yüzden yarıda kalan çekim ertesi açılışta kaldığı
 * yerden sürüyor.
 *
 * Çekimin kendisi 162 istek, yaklaşık iki buçuk dakika. Açılışı bekletmiyor
 * ve bitmesi de garanti değil: Render ücretsiz katmanda süreç ortada
 * uyuyabiliyor. Günlük ([reference_fetch_log]) bu yüzden aile bazında —
 * bir sonraki açılış yalnızca kalanları deniyor.
 */
import type { PoolClient } from 'pg';
import { pool, query } from '../db.js';
import { searchReference } from './marketfiyati.js';
import { boyTutuyorMu, kaynakBoyu, markaTutuyorMu } from './eslestir.js';

const KAYNAK = 'marketfiyati.org.tr';

/** Çağrılar arası bekleme. Kamuya açık, sözleşmesiz bir uca karşı nezaket. */
const BEKLE_MS = 900;

export type Sonuc =
  | 'yazildi'
  | 'sonuc-yok'
  | 'marka-tutmadi'
  | 'boy-tutmadi'
  | 'hata';

export type CekimSonucu = {
  denenen: number;
  yazilan: number;
  /** Sonuç türüne göre aile sayısı. */
  dagilim: Record<Sonuc, number>;
  /** Bugün için geriye kalan aile sayısı. */
  kalan: number;
};

type Kalem = {
  id: string;
  group_name: string;
  brand_name: string | null;
  size_value: string;
  unit: string;
};

const uyu = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Katalog, marka + grup ailelerine bölünmüş hâlde. */
export async function aileler(grup?: string | null): Promise<Map<string, Kalem[]>> {
  // Markasız kalemler dışarıda: kaynakta karşılıkları markalı ürünler ve
  // hangisinin bizim "kilogram domates"imiz olduğu söylenemez. Onlarda
  // sorulacak bir boy da yok.
  const kalemler = await query<Kalem>(
    `SELECT v.id, v.group_name, v.brand_name, v.size_value::text, v.unit::text
       FROM v_canonical_products v
      WHERE v.brand_name IS NOT NULL
        AND ($1::text IS NULL OR v.group_name = $1)
      ORDER BY v.brand_name, v.group_name, v.size_value`,
    [grup ?? null],
  );

  const out = new Map<string, Kalem[]>();
  for (const k of kalemler) {
    const anahtar = `${k.brand_name} ${k.group_name}`;
    const liste = out.get(anahtar) ?? [];
    liste.push(k);
    out.set(anahtar, liste);
  }
  return out;
}

async function tekAile(
  ad: string,
  liste: Kalem[],
  chainIds: Map<string, string>,
  fetchImpl: typeof fetch,
  client?: PoolClient,
): Promise<{ sonuc: Sonuc; yazilan: number }> {
  const calistir = client
    ? (sql: string, params: unknown[]) => client.query(sql, params)
    : (sql: string, params: unknown[]) => query(sql, params);

  let items;
  try {
    // Grup adı "Ekmek, tam buğday" gibi virgüllü; arama için düzleştiriliyor.
    const anahtarKelime = ad.replace(/,/g, ' ').replace(/\s+/g, ' ').trim();
    items = await searchReference(anahtarKelime, 25, fetchImpl);
  } catch {
    return { sonuc: 'hata', yazilan: 0 };
  }

  if (items.length === 0) return { sonuc: 'sonuc-yok', yazilan: 0 };

  let markaTutan = 0;
  let yazilan = 0;

  for (const kalem of liste) {
    const bizimBoy = Number(kalem.size_value);
    for (const item of items) {
      if (!markaTutuyorMu(kalem.brand_name, item.brand)) continue;
      markaTutan++;
      const kaynakBoy = kaynakBoyu(item.sizeText, item.title, kalem.unit);
      if (kaynakBoy === null || !boyTutuyorMu(bizimBoy, kaynakBoy)) continue;

      for (const [chain, fiyat] of item.prices) {
        const merchantId = chainIds.get(chain);
        if (!merchantId) continue;
        await calistir(
          `INSERT INTO reference_prices
             (canonical_product_id, merchant_id, observed_on, price,
              source, source_ref, source_title)
           VALUES ($1, $2, COALESCE($3::date, current_date), $4, $5, $6, $7)
           ON CONFLICT (canonical_product_id, merchant_id, observed_on, source_ref)
           DO UPDATE SET price = EXCLUDED.price,
                         source_title = EXCLUDED.source_title,
                         fetched_at = now()`,
          [
            kalem.id,
            merchantId,
            item.observedOn,
            fiyat,
            KAYNAK,
            item.ref,
            item.title,
          ],
        );
        yazilan++;
      }
    }
  }

  if (yazilan > 0) return { sonuc: 'yazildi', yazilan };
  return { sonuc: markaTutan === 0 ? 'marka-tutmadi' : 'boy-tutmadi', yazilan: 0 };
}

/**
 * Bugün henüz denenmemiş aileleri çeker.
 *
 * [limit] verilirse o kadar aile denenip bırakılıyor — açılışta bütün
 * çekimi tek seferde yapmak zorunda değiliz, ertesi çağrı kalanı alıyor.
 */
export async function refreshReference(
  opts: {
    limit?: number;
    grup?: string | null;
    /** Günlüğe bakmadan hepsini yeniden dene. */
    force?: boolean;
    onFamily?: (ad: string, sonuc: Sonuc, yazilan: number) => void;
    /** Testler ağa çıkmasın diye. */
    fetchImpl?: typeof fetch;
    /** Testler beklemesin diye. */
    bekleMs?: number;
  } = {},
): Promise<CekimSonucu> {
  const hepsi = await aileler(opts.grup);

  const yapilmis = opts.force
    ? new Set<string>()
    : new Set(
        (
          await query<{ family: string }>(
            `SELECT family FROM reference_fetch_log WHERE fetched_on = current_date`,
          )
        ).map((r) => r.family),
      );

  const bekleyen = [...hepsi].filter(([ad]) => !yapilmis.has(ad));

  const chainRows = await query<{ id: string; chain_code: string }>(
    `SELECT id, chain_code FROM merchants`,
  );
  const chainIds = new Map(chainRows.map((r) => [r.chain_code, r.id]));

  const dagilim: Record<Sonuc, number> = {
    yazildi: 0,
    'sonuc-yok': 0,
    'marka-tutmadi': 0,
    'boy-tutmadi': 0,
    hata: 0,
  };

  let denenen = 0;
  let yazilan = 0;
  const limit = opts.limit ?? Infinity;

  for (const [ad, liste] of bekleyen) {
    if (denenen >= limit) break;
    denenen++;

    const { sonuc, yazilan: n } = await tekAile(
      ad,
      liste,
      chainIds,
      opts.fetchImpl ?? fetch,
    );
    dagilim[sonuc]++;
    yazilan += n;
    opts.onFamily?.(ad, sonuc, n);

    // Sonuç ne olursa olsun günlüğe yazılıyor — 'sonuc-yok' da bir cevap ve
    // o aileyi bugünlük kapatıyor. Yazılmasaydı karşılığı olmayan aileler
    // her açılışta yeniden denenir, kaynağa boşuna yük binerdi.
    await query(
      `INSERT INTO reference_fetch_log (fetched_on, family, outcome, written)
       VALUES (current_date, $1, $2, $3)
       ON CONFLICT (fetched_on, family)
       DO UPDATE SET outcome = EXCLUDED.outcome,
                     written = EXCLUDED.written,
                     at = now()`,
      [ad, sonuc, n],
    );

    await uyu(opts.bekleMs ?? BEKLE_MS);
  }

  return { denenen, yazilan, dagilim, kalan: bekleyen.length - denenen };
}

/** Betikler için: havuzu kapatarak biten sarmalayıcı. */
export async function refreshReferenceCli(
  opts: Parameters<typeof refreshReference>[0] = {},
): Promise<CekimSonucu> {
  try {
    return await refreshReference(opts);
  } finally {
    await pool.end();
  }
}
