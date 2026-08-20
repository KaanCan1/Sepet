import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { query } from '../db.js';

export const productsRouter = Router();
productsRouter.use(requireAuth);

/** Ürünler sekmesi: sepetteki kalemler, 12 aylık değişime göre. */
productsRouter.get('/', async (req: AuthedRequest, res) => {
  const rows = await query(
    `SELECT canonical_product_id, name, size_label, observations,
            merchant_count, month_span,
            first_unit_price, last_unit_price
       FROM v_product_summary
      WHERE user_id = $1
      ORDER BY (last_unit_price / nullif(first_unit_price, 0)) DESC NULLS LAST`,
    [req.userId],
  );
  res.json(
    rows.map((r) => ({
      id: r.canonical_product_id,
      name: r.name,
      sizeLabel: r.size_label,
      observations: r.observations,
      merchantCount: r.merchant_count,
      monthSpan: r.month_span,
      changePct:
        r.first_unit_price > 0
          ? Number(
              (
                (r.last_unit_price / r.first_unit_price - 1) *
                100
              ).toFixed(1),
            )
          : null,
    })),
  );
});

/** Ekran 03: tek ürünün geçmişi. */
productsRouter.get('/:id', async (req: AuthedRequest, res) => {
  const [summary] = await query(
    `SELECT * FROM v_product_summary WHERE user_id = $1 AND canonical_product_id = $2`,
    [req.userId, req.params.id],
  );
  if (!summary) {
    res.status(404).json({ error: 'Ürün bulunamadı' });
    return;
  }

  // Grafik gerçek gözlemleri gösteriyor, taşınmış ayları değil — düz bir
  // çizgi "fiyat sabit kaldı" der, oysa sadece bakmamışız.
  const history = await query(
    `SELECT observed_on, unit_price, pack_price
       FROM price_observations
      WHERE user_id = $1 AND canonical_product_id = $2 AND NOT is_outlier
      ORDER BY observed_on`,
    [req.userId, req.params.id],
  );

  const byMerchant = await query(
    `SELECT merchant_name, pack_price, unit_price, observed_on
       FROM v_product_by_merchant
      WHERE user_id = $1 AND canonical_product_id = $2
      ORDER BY unit_price`,
    [req.userId, req.params.id],
  );

  res.json({
    id: summary.canonical_product_id,
    name: summary.name,
    sizeLabel: summary.size_label,
    observations: summary.observations,
    merchantCount: summary.merchant_count,
    monthSpan: summary.month_span,
    firstPackPrice: summary.first_pack_price,
    lastPackPrice: summary.last_pack_price,
    changePct:
      summary.first_unit_price > 0
        ? Number(
            ((summary.last_unit_price / summary.first_unit_price - 1) * 100).toFixed(1),
          )
        : null,
    history: history.map((h) => ({
      date: h.observed_on,
      unitPrice: h.unit_price,
      packPrice: h.pack_price,
    })),
    byMerchant: byMerchant.map((m) => ({
      merchant: m.merchant_name,
      packPrice: m.pack_price,
      unitPrice: m.unit_price,
      seenOn: m.observed_on,
    })),
  });
});

/** Eşleşme sorusundaki adaylar — kanonik ürün araması. */
productsRouter.get('/catalog/search', async (req, res) => {
  const q = String(req.query.q ?? '').trim();
  const rows = await query(
    `SELECT id, name, size_label FROM canonical_products
      WHERE normalize_raw_text(name || ' ' || size_label) LIKE '%' || normalize_raw_text($1) || '%'
      ORDER BY name LIMIT 20`,
    [q],
  );
  res.json(
    rows.map((r) => ({ id: r.id, name: r.name, sizeLabel: r.size_label })),
  );
});
