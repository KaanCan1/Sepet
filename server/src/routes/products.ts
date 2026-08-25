import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { query } from '../db.js';
import { matchCatalog } from '../catalog-match.js';

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

/**
 * Ham fiş metni için sıralı aday listesi.
 *
 * Eşleşme ekranı açılırken çağrılıyor: kullanıcı arama kutusuna bir şey
 * yazmadan önce doğru ürün zaten listenin başında duruyor.
 *
 * `sizeAmbiguous` true ise marka ve grup çözülmüş, geriye yalnızca gramaj
 * kalmıştır — arayüz o durumda tam listeyi değil, aynı ürünün boylarını
 * sormalı.
 */
productsRouter.get('/catalog/suggest', async (req, res) => {
  const raw = String(req.query.raw ?? '').trim();
  if (!raw) {
    res.status(400).json({ error: 'raw gerekli' });
    return;
  }
  const outcome = await matchCatalog(raw, 6);

  // Boy sorulacaksa listeyi aday havuzundan süzmek yetmez: aday sayısı
  // sınırlı ve katalog büyüdükçe markanın boyları kesilebilir. O yüzden
  // aynı marka + grubun boyları ayrıca ve tam olarak çekiliyor.
  const top = outcome.candidates[0];
  const sizes =
    outcome.sizeAmbiguous && top
      ? await query(
          `SELECT id, short_name, group_name, brand_name, size_label,
                  size_value, unit
             FROM v_canonical_products
            WHERE group_id = $1
              AND coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
                  = coalesce($2::uuid, '00000000-0000-0000-0000-000000000000'::uuid)
            ORDER BY size_value`,
          [top.groupId, top.brandId],
        )
      : [];

  res.json({
    sizeAmbiguous: outcome.sizeAmbiguous,
    autoId: outcome.auto?.id ?? null,
    sizes: sizes.map((r) => ({
      id: r.id,
      name: r.short_name,
      groupName: r.group_name,
      brand: r.brand_name,
      sizeLabel: r.size_label,
      sizeValue: Number(r.size_value),
      unit: r.unit,
    })),
    candidates: outcome.candidates.map((c) => ({
      id: c.id,
      name: c.shortName,
      groupId: c.groupId,
      groupName: c.groupName,
      brandId: c.brandId,
      brand: c.brandName,
      sizeLabel: c.sizeLabel,
      sizeValue: c.sizeValue,
      unit: c.unit,
      score: c.score,
    })),
  });
});

/**
 * Katalogda olmayan bir boyu ekler.
 *
 * Katalog rafta yaygın paketleri taşıyor ama hepsini taşıyamaz. Eksik boy
 * için kullanıcının yapabileceği tek şey yanlış bir boy seçmek olurdu ve
 * endeks birim fiyattan hesaplandığı için bu sessizce yanlış enflasyon
 * demek. Eklenen kalem kataloğun kendisine giriyor — aynı marka + grup +
 * boy ikinci kez istendiğinde mevcut olan dönüyor, yenisi açılmıyor.
 */
productsRouter.post('/catalog', async (req: AuthedRequest, res) => {
  const { groupId, brandId, sizeLabel, sizeValue } = req.body ?? {};
  const value = Number(sizeValue);
  if (!groupId || !sizeLabel || !Number.isFinite(value) || value <= 0) {
    res
      .status(400)
      .json({ error: 'groupId, sizeLabel ve pozitif sizeValue gerekli' });
    return;
  }

  const [row] = await query(
    `WITH yeni AS (
       INSERT INTO canonical_products (group_id, brand_id, size_label, size_value)
       VALUES ($1, $2, btrim($3), $4)
       ON CONFLICT DO NOTHING
       RETURNING id
     )
     SELECT id FROM yeni
     UNION ALL
     SELECT id FROM canonical_products
      WHERE group_id = $1
        AND coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
            = coalesce($2::uuid, '00000000-0000-0000-0000-000000000000'::uuid)
        AND size_label = btrim($3)
     LIMIT 1`,
    [groupId, brandId ?? null, sizeLabel, value],
  );

  if (!row) {
    res.status(400).json({ error: 'Ürün grubu bulunamadı' });
    return;
  }

  const [full] = await query(
    `SELECT id, short_name, group_name, brand_name, size_label
       FROM v_canonical_products WHERE id = $1`,
    [row.id],
  );
  res.status(201).json({
    id: full!.id,
    name: full!.short_name,
    groupName: full!.group_name,
    brand: full!.brand_name,
    sizeLabel: full!.size_label,
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
 * Ürün grupları — istenirse ölçü birimine göre süzülmüş.
 *
 * Gramaj ekranı bunu, kullanıcının seçtiği birim grubun birimiyle
 * uyuşmadığında çağırıyor. Fişte "TACIROGLU SUT" yazan kalem aslında
 * kaşar peyniriyse kullanıcı gram girmek ister; ama 400 g'ı "Süt, tam
 * yağlı" grubunda saklamak endeksin birimini bozar — o grup litre
 * cinsinden ve birim fiyat "litre fiyatı" diye yazılır.
 *
 * Yanlış olan birim değil grup. Bu uç nokta doğru grubu seçtiriyor:
 * marka korunuyor, kalem kilogram cinsinden bir gruba giriyor.
 */
productsRouter.get('/catalog/groups', async (req, res) => {
  const unit = String(req.query.unit ?? '').trim();
  const q = String(req.query.q ?? '').trim();
  const rows = await query<{ id: string; name: string; unit: string }>(
    `SELECT id, name, unit FROM product_groups
      WHERE ($1 = '' OR unit::text = $1)
        AND ($2 = '' OR normalize_raw_text(name)
             LIKE '%' || normalize_raw_text($2) || '%')
      ORDER BY name
      LIMIT 40`,
    [unit, q],
  );
  res.json(rows.map((r) => ({ id: r.id, name: r.name, unit: r.unit })));
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
    observed_on: string;
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
