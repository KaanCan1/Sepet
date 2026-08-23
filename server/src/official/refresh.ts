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

/** Seviyeleri yıllık değişime çevirip yazar. Testler bunu doğrudan çağırıyor. */
export async function writeLevels(
  seriesId: string,
  levels: Level[],
): Promise<RefreshResult> {
  const rows = yearlyChanges(levels);
  if (rows.length === 0) return { written: 0 };

  for (const r of rows) {
    await query(
      `INSERT INTO official_index_levels (series_id, month, yoy_pct, published_at)
       VALUES ($1, $2::date, $3, current_date)
       ON CONFLICT (series_id, month)
       DO UPDATE SET yoy_pct = EXCLUDED.yoy_pct,
                     published_at = EXCLUDED.published_at`,
      [seriesId, r.month, r.yoyPct],
    );
  }

  const { newest } = await one<{ newest: string | null }>(
    `SELECT to_char(max(month), 'YYYY-MM-DD') AS newest
       FROM official_index_levels WHERE series_id = $1`,
    [seriesId],
  );
  return { written: rows.length, newestMonth: newest ?? undefined };
}
