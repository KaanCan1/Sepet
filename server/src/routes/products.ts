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
  // Arama görünen adın tamamında: marka + grup + boy. Böylece "sutas"
  // da "yogurt" da "1.5 kg" da aynı kalemi buluyor.
  const brand = String(req.query.brand ?? '').trim();
  const rows = await query(
    `SELECT id, short_name, group_name, brand_name, size_label, size_value
       FROM v_canonical_products
      WHERE normalize_raw_text(display_name)
            LIKE '%' || normalize_raw_text($1) || '%'
        AND ($2 = '' OR normalize_raw_text(coalesce(brand_name, ''))
            LIKE '%' || normalize_raw_text($2) || '%')
      ORDER BY group_name, brand_name NULLS FIRST, size_value
      LIMIT 20`,
    [q, brand],
  );
  res.json(
    rows.map((r) => ({
      id: r.id,
      name: r.short_name,
      groupName: r.group_name,
      brand: r.brand_name,
      sizeLabel: r.size_label,
    })),
  );
});

/**
 * Aynı grup ve boyda markalar arası fiyat farkı: "1,5 kg yoğurt kimde kaça".
 *
 * Karşılaştırma birim fiyat üzerinden, çünkü 1 kg ile 1,5 kg paketin
 * etiket fiyatı doğrudan kıyaslanamaz. Yalnızca kullanıcının kendi
 * gözlemleri — raftan çekilmiş fiyat yok.
 */
productsRouter.get('/groups/:id/spread', async (req: AuthedRequest, res) => {
  const rows = await query<{
    canonical_product_id: string;
    group_name: string;
    brand_name: string | null;
    size_label: string;
    unit_price: number;
    pack_price: number;
    observed_on: Date;
    merchant_name: string;
  }>(
    `SELECT canonical_product_id, group_name, brand_name, size_label,
            unit_price, pack_price, observed_on, merchant_name
       FROM v_group_price_spread
      WHERE user_id = $1 AND group_id = $2
      ORDER BY unit_price`,
    [req.userId, req.params.id],
  );

  if (!rows.length) {
    res.status(404).json({ error: 'Bu grupta gözlemin yok' });
    return;
  }

  const items = rows.map((r) => ({
    productId: r.canonical_product_id,
    brand: r.brand_name,
    sizeLabel: r.size_label,
    unitPrice: r.unit_price,
    packPrice: r.pack_price,
    seenOn: r.observed_on,
    merchant: r.merchant_name,
  }));

  const cheapest = items[0]!;
  const dearest = items[items.length - 1]!;

  res.json({
    groupName: rows[0]!.group_name,
    items,
    cheapest,
    dearest,
    // Tek marka gözlendiyse fark yok; 0 dönmek "aynı fiyat" demek değil,
    // "kıyaslayacak ikinci kalem yok" demek. İstemci bunu ayırt etsin diye
    // spreadPct yalnızca en az iki kalem varken dolu.
    spreadPct:
      items.length > 1 && cheapest.unitPrice > 0
        ? Math.round(((dearest.unitPrice / cheapest.unitPrice) - 1) * 1000) / 10
        : null,
  });
});
