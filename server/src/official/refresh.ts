import { one, query } from '../db.js';
import { fetchLevels, yearlyChanges, type Level } from './evds.js';

/** Kaç gün geçtikten sonra yeniden çekilsin. */
const STALE_DAYS = 20;

export interface RefreshResult {
  /** Yazılan ay sayısı. */
  written: number;
  /** Atlandıysa sebebi. */
  skipped?: 'no-key' | 'fresh';
  newestMonth?: string;
}

/**
 * TÜİK TÜFE'yi EVDS'ten çekip veritabanına yazar.
 *
 * Anahtar yoksa sessizce atlıyor: elle giriş yolu duruyor ve uygulama
 * anahtarsız da çalışmak zorunda.
 *
 * [force] verilmezse tazelik kontrolü yapılıyor. Render ücretsiz katmanda
 * servis sık sık uyanıyor; her uyanışta TCMB'ye gitmenin anlamı yok, seri
 * ayda bir açıklanıyor.
 */
export async function refreshOfficial(
  opts: { apiKey?: string; force?: boolean; fetchImpl?: typeof fetch } = {},
): Promise<RefreshResult> {
  const apiKey = opts.apiKey ?? process.env.EVDS_API_KEY;
  if (!apiKey) return { written: 0, skipped: 'no-key' };

  const series = await query<{ id: string }>(
    `SELECT id FROM official_series WHERE code = 'TUIK_TUFE'`,
  );
  if (series.length === 0) return { written: 0 };
  const seriesId = series[0]!.id;

  if (!opts.force) {
    const [fresh] = await query<{ recent: boolean }>(
      `SELECT max(published_at) > current_date - $1::int AS recent
         FROM official_index_levels WHERE series_id = $2`,
      [STALE_DAYS, seriesId],
    );
    if (fresh?.recent) return { written: 0, skipped: 'fresh' };
  }

  const levels = await fetchLevels({ apiKey, fetchImpl: opts.fetchImpl });
  return writeLevels(seriesId, levels);
}

/**
 * Seviyeleri ve onlardan çıkan yıllık değişimi yazar. Testler bunu doğrudan
 * çağırıyor.
 *
 * Seviye de saklanıyor, çünkü manşetteki yıllık yüzde grafiğe çizilemiyor:
 * yıllık değişim serisinden aylık bir yol geri türetilemez. Grafikte iki
 * çizgiyi yan yana koymak için TÜİK'in ay ay seviyesi gerekiyor.
 *
 * Saklanan seviye MUTLAK bir sayı olarak okunmamalı, yalnızca aynı serinin
 * başka aylarıyla oranlanmalı. Taban yılı değiştiğinde (2003=100 → 2025=100)
 * EVDS yeni bir seri kodu açıyor; kod güncellenene kadar eski tabandaki
 * satırlar elde kalır ve iki tabanı birbirine bölen bir oran anlamsız olur.
 * Grafik bu yüzden ham seviyeyi hiç göstermiyor, ortak bir aya 100'lüyor —
 * ve yalnızca son aylara bakıyor; her tazeleme o pencereyi baştan yazıyor.
 *
 * Yıllık değişim seviyeden hesaplanıyor: EVDS'in ayrı yıllık serisi taban
 * yılı değişiminde kopuyor, aynı serinin kendi içinde oranlamak kopmuyor.
 * On iki ay öncesi elde yoksa o ay yüzdesiz yazılıyor — seviyesi var,
 * yüzdesi yok; uydurulmuyor.
 */
export async function writeLevels(
  seriesId: string,
  levels: Level[],
): Promise<RefreshResult> {
  if (levels.length === 0) return { written: 0 };

  const yoyByMonth = new Map(
    yearlyChanges(levels).map((r) => [r.month, r.yoyPct]),
  );

  for (const l of levels) {
    await query(
      `INSERT INTO official_index_levels (series_id, month, level, yoy_pct, published_at)
       VALUES ($1, $2::date, $3, $4, current_date)
       ON CONFLICT (series_id, month)
       -- coalesce şart: elle girilen bir ay, seviyesi yazılırken yüzdesini
       -- kaybetmemeli. EVDS'ten yeni bir değer gelirse o kazanıyor.
       DO UPDATE SET level = coalesce(EXCLUDED.level, official_index_levels.level),
                     yoy_pct = coalesce(EXCLUDED.yoy_pct, official_index_levels.yoy_pct),
                     published_at = EXCLUDED.published_at`,
      [seriesId, l.month, l.level, yoyByMonth.get(l.month) ?? null],
    );
  }

  const { newest } = await one<{ newest: string | null }>(
    `SELECT to_char(max(month), 'YYYY-MM-DD') AS newest
       FROM official_index_levels WHERE series_id = $1`,
    [seriesId],
  );
  return { written: levels.length, newestMonth: newest ?? undefined };
}
