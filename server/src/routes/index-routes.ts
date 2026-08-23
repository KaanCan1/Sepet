import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { query } from '../db.js';

export const indexRouter = Router();
indexRouter.use(requireAuth);

/**
 * Ekran 01. Manşet + kendi serin + resmî seriler.
 *
 * 12 ay dolmamışsa yıllıklandırma yapılmaz: `windowMonths` gerçek pencereyi
 * söyler ve ekrandaki etiket ("SON 12 AY") ona göre yazılır.
 */
indexRouter.get('/', async (req: AuthedRequest, res) => {
  const userId = req.userId!;

  const [headline] = await query<{
    change_pct: number | null;
    window_months: number;
    current_month: string;
    covered_weight: number;
  }>(
    // to_char: DATE'i Date nesnesine çevirtmiyoruz, saat dilimi kaydırması
    // ayın 1'ini bir önceki aya düşürüyor.
    `SELECT change_pct, window_months, covered_weight,
            to_char(current_month, 'YYYY-MM-DD') AS current_month
       FROM v_index_headline WHERE user_id = $1`,
    [userId],
  );

  if (!headline) {
    // Resmî seri kullanıcının verisine bağlı değil; hiç fişi olmayan
    // hesapta da gönderiliyor. Eskiden boş dizi dönüyordu ve ilk açılışta
    // ekran tamamen boş kalıyordu — kullanıcı ne yapacağını göremiyordu.
    res.json({ headline: null, series: [], official: await officialSeries() });
    return;
  }

  const series = await query<{ month: string; level: number; mom_pct: number }>(
    `SELECT to_char(month, 'YYYY-MM-DD') AS month, level, mom_pct
       FROM v_index_series
      WHERE user_id = $1 ORDER BY month`,
    [userId],
  );

  // Geçen aya göre kaç puan oynadı — rozetteki sayı.
  const [delta] = await query<{ delta: number | null }>(
    `WITH h AS (SELECT current_month FROM v_index_headline WHERE user_id = $1)
     SELECT round(
              (SELECT level FROM index_levels
                WHERE user_id = $1 AND month = h.current_month)
              / nullif((SELECT level FROM index_levels
                         WHERE user_id = $1
                           AND month = h.current_month - interval '1 month'), 0)
              * 100 - 100, 1) AS delta
       FROM h`,
    [userId],
  );

  const official = await officialSeries();

  res.json({
    headline: {
      changePct: headline.change_pct,
      windowMonths: headline.window_months,
      month: headline.current_month,
      coveredWeight: headline.covered_weight,
      monthDeltaPoints: delta?.delta ?? null,
    },
    series: series.map((r) => ({
      month: r.month,
      level: r.level,
      momPct: r.mom_pct,
    })),
    official,
  });
});

/** Ekran 04'ün alt kısmı: bu ay en çok zamlananlar. */
indexRouter.get('/movers', async (req: AuthedRequest, res) => {
  const rows = await query<{
    canonical_product_id: string;
    name: string;
    size_label: string;
    change_pct: number;
  }>(
    `SELECT canonical_product_id, name, size_label, change_pct
       FROM v_monthly_movers
      WHERE user_id = $1
        AND month = (SELECT max(month) FROM v_monthly_movers WHERE user_id = $1)
      ORDER BY change_pct DESC`,
    [req.userId],
  );
  res.json(
    rows.map((r) => ({
      productId: r.canonical_product_id,
      name: r.name,
      sizeLabel: r.size_label,
      changePct: r.change_pct,
    })),
  );
});

/**
 * Kategori kırılımı: hangi harcama kalemi kişisel enflasyonu sürüklüyor.
 *
 * Aynı zincirleme, kategoriye kısıtlanmış küme üzerinde ve ağırlıklar küme
 * içinde yeniden normalize edilerek hesaplanıyor. Genel endeksin alt
 * kalemleri değil, bağımsız serileri — biri diğerine toplanmıyor.
 */
indexRouter.get('/by-category', async (req: AuthedRequest, res) => {
  // Ay SQL'de metne çevriliyor, Date olarak değil. pg bir DATE sütununu
  // YEREL geceyarısı Date'i yapıyor; JSON'a giderken toISOString() bunu
  // UTC'ye çevirdiği için UTC+3'te ayın 1'i bir önceki ayın 31'ine kayıyor
  // ve ekranda Ağustos seviyesi "Temmuz" diye etiketleniyordu.
  const rows = await query<{
    category_id: string;
    category_code: string;
    category_name: string;
    month: string;
    level: number;
    covered_weight: number;
  }>(
    `SELECT category_id, category_code, category_name,
            to_char(month, 'YYYY-MM-DD') AS month,
            level, covered_weight
       FROM v_index_by_category
      WHERE user_id = $1
      ORDER BY category_name, month`,
    [req.userId],
  );

  // Kategori başına tek nesne; seri içinde aylar sırada.
  const byCategory = new Map<string, {
    categoryId: string;
    code: string;
    name: string;
    latestLevel: number;
    series: Array<{ month: string; level: number; coveredWeight: number }>;
  }>();

  for (const r of rows) {
    const month = r.month;
    let entry = byCategory.get(r.category_id);
    if (!entry) {
      entry = {
        categoryId: r.category_id,
        code: r.category_code,
        name: r.category_name,
        latestLevel: r.level,
        series: [],
      };
      byCategory.set(r.category_id, entry);
    }
    entry.series.push({ month, level: r.level, coveredWeight: r.covered_weight });
    entry.latestLevel = r.level;
  }

  res.json(
    [...byCategory.values()].sort((a, b) => b.latestLevel - a.latestLevel),
  );
});

/**
 * Marka kırılımı. Yalnızca markalı kalemler: kasada tartılan sebzenin
 * markası yok, uydurulmuyor — o kalemler bu seride hiç yer almıyor.
 */
indexRouter.get('/by-brand', async (req: AuthedRequest, res) => {
  const rows = await query<{
    brand_id: string;
    brand_name: string;
    month: string;
    level: number;
    covered_weight: number;
  }>(
    `SELECT brand_id, brand_name,
            to_char(month, 'YYYY-MM-DD') AS month,
            level, covered_weight
       FROM v_index_by_brand
      WHERE user_id = $1
      ORDER BY brand_name, month`,
    [req.userId],
  );

  const byBrand = new Map<string, {
    brandId: string;
    name: string;
    latestLevel: number;
    series: Array<{ month: string; level: number; coveredWeight: number }>;
  }>();

  for (const r of rows) {
    const month = r.month;
    let entry = byBrand.get(r.brand_id);
    if (!entry) {
      entry = { brandId: r.brand_id, name: r.brand_name, latestLevel: r.level, series: [] };
      byBrand.set(r.brand_id, entry);
    }
    entry.series.push({ month, level: r.level, coveredWeight: r.covered_weight });
    entry.latestLevel = r.level;
  }

  res.json([...byBrand.values()].sort((a, b) => b.latestLevel - a.latestLevel));
});

/// Karşılaştırma serileri ve her birinin en son girilmiş yıllık değişimi.
///
/// Kullanıcıdan bağımsız: endeksi olmayan hesapta da gönderiliyor, çünkü
/// TÜİK sayısı o hesabın fişlerine bağlı değil.
async function officialSeries(): Promise<
  Array<{
    code: string;
    publisher: string;
    name: string;
    isOfficial: boolean;
    yoyPct: number | null;
  }>
> {
  // Alan adları BURADA çevriliyor, çağıranda değil. İlk yazışta çevirme
  // yalnızca dolu daldaydı; boş dalda ham satırlar gidiyor ve uygulama
  // yoyPct yerine yoy_pct görüp değeri null sanıyordu — TÜİK sayısı
  // girilmiş olmasına rağmen ekranda "—" çıkıyordu.
  const rows = await query<{
    code: string;
    publisher: string;
    name: string;
    is_official: boolean;
    yoy_pct: number | null;
  }>(
    `SELECT DISTINCT ON (s.id)
            s.code, s.publisher, s.name, s.is_official, l.yoy_pct
       FROM official_series s
       LEFT JOIN official_index_levels l ON l.series_id = s.id
      ORDER BY s.id, l.month DESC NULLS LAST`,
  );
  return rows.map((r) => ({
    code: r.code,
    publisher: r.publisher,
    name: r.name,
    isOfficial: r.is_official,
    yoyPct: r.yoy_pct,
  }));
}
