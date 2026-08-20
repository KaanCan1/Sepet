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
    current_month: Date;
    covered_weight: number;
  }>(`SELECT * FROM v_index_headline WHERE user_id = $1`, [userId]);

  if (!headline) {
    res.json({ headline: null, series: [], official: [] });
    return;
  }

  const series = await query<{ month: Date; level: number; mom_pct: number }>(
    `SELECT month, level, mom_pct FROM v_index_series
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

  const official = await query<{
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
    official: official.map((r) => ({
      code: r.code,
      publisher: r.publisher,
      name: r.name,
      isOfficial: r.is_official,
      yoyPct: r.yoy_pct,
    })),
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
