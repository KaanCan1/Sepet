import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { pool, query } from '../db.js';
import { matchCatalog } from '../catalog-match.js';
import { isNonIndexLine } from '../non-index.js';

export const receiptsRouter = Router();
receiptsRouter.use(requireAuth);

receiptsRouter.get('/', async (req: AuthedRequest, res) => {
  const rows = await query(
    `SELECT r.id, m.name AS merchant, r.purchased_at, r.total_amount,
            count(l.id)::int AS item_count,
            count(*) FILTER (WHERE l.status = 'pending')::int AS pending_count
       FROM receipts r
       JOIN merchants m ON m.id = r.merchant_id
       LEFT JOIN receipt_lines l ON l.receipt_id = r.id
      WHERE r.user_id = $1
      GROUP BY r.id, m.name
      ORDER BY r.purchased_at DESC, r.created_at DESC`,
    [req.userId],
  );
  res.json(
    rows.map((r) => ({
      id: r.id,
      merchant: r.merchant,
      purchasedAt: r.purchased_at,
      total: r.total_amount,
      itemCount: r.item_count,
      pendingCount: r.pending_count,
    })),
  );
});

receiptsRouter.get('/:id', async (req: AuthedRequest, res) => {
  const [receipt] = await query(
    `SELECT r.id, m.name AS merchant, r.purchased_at, r.total_amount
       FROM receipts r JOIN merchants m ON m.id = r.merchant_id
      WHERE r.id = $1 AND r.user_id = $2`,
    [req.params.id, req.userId],
  );
  if (!receipt) {
    res.status(404).json({ error: 'Fiş bulunamadı' });
    return;
  }

  const lines = await query(
    `SELECT l.id, l.line_no, l.raw_text, l.quantity, l.line_amount, l.status,
            cp.display_name AS name, cp.brand_name, cp.size_label
       FROM receipt_lines l
       LEFT JOIN v_canonical_products cp ON cp.id = l.canonical_product_id
      WHERE l.receipt_id = $1
      ORDER BY l.line_no`,
    [req.params.id],
  );

  res.json({
    id: receipt.id,
    merchant: receipt.merchant,
    purchasedAt: receipt.purchased_at,
    total: receipt.total_amount,
    lines: lines.map((l) => ({
      id: l.id,
      lineNo: l.line_no,
      raw: l.raw_text,
      quantity: l.quantity,
      amount: l.line_amount,
      status: l.status,
      // display_name zaten marka + grup + boy; ayrıca boy eklenmiyor.
      canonical: l.name ?? null,
      brand: l.brand_name ?? null,
    })),
  });
});

interface LineBody {
  raw: string;
  quantity?: number;
  amount: number;
  canonicalProductId?: string | null;
}

/**
 * Fiş kaydı. Satırlar tek işlemde yazılır; yarım fiş endeksi bozar.
 *
 * Ham metin market bazlı alias tablosunda aranır — daha önce çözülmüş bir
 * eşleşme varsa satır doğrudan `auto` olur ve modele hiç gidilmez. Aksi hâlde
 * `pending` kalır ve kullanıcıya "eşleşme?" olarak sorulur.
 */
receiptsRouter.post('/', async (req: AuthedRequest, res) => {
  const { merchantId, purchasedAt, lines } = req.body ?? {};
  if (!merchantId || !purchasedAt || !Array.isArray(lines) || !lines.length) {
    res
      .status(400)
      .json({ error: 'merchantId, purchasedAt ve en az bir satır gerekli' });
    return;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const total = (lines as LineBody[]).reduce(
      (a, l) => a + Number(l.amount ?? 0),
      0,
    );
    const { rows } = await client.query<{ id: string }>(
      `INSERT INTO receipts (user_id, merchant_id, purchased_at, total_amount)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [req.userId, merchantId, purchasedAt, total],
    );
    const receiptId = rows[0]!.id;

    for (const [i, line] of (lines as LineBody[]).entries()) {
      // Bilinen eşleşme var mı? Varsa soru sorma.
      const { rows: alias } = await client.query<{ canonical_product_id: string }>(
        `SELECT canonical_product_id FROM product_aliases
          WHERE merchant_id = $1
            AND raw_text_normalized = normalize_raw_text($2)`,
        [merchantId, line.raw],
      );
      let productId =
        line.canonicalProductId ?? alias[0]?.canonical_product_id ?? null;
      let confidence: number | null = productId && alias[0] ? 1 : null;

      // Alias yoksa katalogda bulanık aranıyor. Yazarkasa ürün adını kesiyor
      // ("MIGROS T.YAGLI YOGU."), birebir arama bunu hiç bulamıyordu.
      //
      // Otomatik bağlama yalnızca aday tek başına net olduğunda. Boy belirsizse
      // — aynı marka ve grubun 1 kg ile 3 kg'ı yan yana geldiğinde — soru
      // kullanıcıya gidiyor: gramaj fişte yazmıyor ve endeks birim fiyat
      // üzerinden hesaplandığı için yanlış tahmin sessizce yanlış enflasyon
      // üretir.
      // Kasa poşeti gibi ürün olmayan kalemler endeks dışı. Sorulmuyor da:
      // doğru cevabı yok.
      const nonIndex = !productId && isNonIndexLine(line.raw);

      if (!productId && !nonIndex) {
        const outcome = await matchCatalog(line.raw, 5, client);
        if (outcome.auto) {
          productId = outcome.auto.id;
          confidence = outcome.auto.score;
        }
      }

      const status = productId ? 'auto' : nonIndex ? 'excluded' : 'pending';

      await client.query(
        `INSERT INTO receipt_lines
           (receipt_id, line_no, raw_text, quantity, line_amount,
            canonical_product_id, status, match_confidence)
         VALUES ($1, $2, $3, $4, $5, $6, $7::match_status, $8)`,
        [
          receiptId,
          i + 1,
          line.raw,
          line.quantity ?? 1,
          line.amount,
          productId,
          status,
          confidence,
        ],
      );
    }

    await client.query('SELECT refresh_user_index($1)', [req.userId]);
    await client.query('COMMIT');
    res.status(201).json({ id: receiptId });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

/**
 * "eşleşme?" sorusunun cevabı.
 *
 * Onay yalnızca bu satırı düzeltmiyor: aynı market + aynı ham metin için
 * alias tablosuna yazılıyor, böylece aynı fiş formatı bir daha sorulmuyor.
 */
receiptsRouter.post('/:id/lines/:lineId/match', async (req: AuthedRequest, res) => {
  const { canonicalProductId } = req.body ?? {};
  if (!canonicalProductId) {
    res.status(400).json({ error: 'canonicalProductId gerekli' });
    return;
  }

  const [line] = await query<{ raw_text: string; merchant_id: string }>(
    `SELECT l.raw_text, r.merchant_id
       FROM receipt_lines l
       JOIN receipts r ON r.id = l.receipt_id
      WHERE l.id = $1 AND l.receipt_id = $2 AND r.user_id = $3`,
    [req.params.lineId, req.params.id, req.userId],
  );
  if (!line) {
    res.status(404).json({ error: 'Satır bulunamadı' });
    return;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE receipt_lines
          SET canonical_product_id = $1, status = 'confirmed', match_confidence = 1
        WHERE id = $2`,
      [canonicalProductId, req.params.lineId],
    );
    await client.query(
      `INSERT INTO product_aliases
         (merchant_id, raw_text_normalized, canonical_product_id)
       VALUES ($1, normalize_raw_text($2), $3)
       ON CONFLICT (merchant_id, raw_text_normalized)
       DO UPDATE SET canonical_product_id = EXCLUDED.canonical_product_id,
                     confirmations = product_aliases.confirmations + 1`,
      [line.merchant_id, line.raw_text, canonicalProductId],
    );
    await client.query('SELECT refresh_user_index($1)', [req.userId]);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  res.json({ ok: true });
});

/// Kullanıcının bütün fişlerini ve türetilmiş endeksini siler; hesabı bırakır.
///
/// Demo veriyle denendikten sonra gerçek fişlere geçerken gereken şey bu:
/// hesap, izinler ve öğrenilmiş eşleşmeler kalsın, ama endeks sıfırdan
/// kendi harcamanla kurulsun.
///
/// Öğrenilmiş eşleşmeler (product_aliases) BİLEREK duruyor. Onlar kullanıcıya
/// değil markete bağlı ve "şu ham metin şu üründür" bilgisi demo veriyle
/// öğrenilmiş olsa da doğru; silmek ilk gerçek fişte gereksiz soru sordururdu.
/**
 * Tek fişi siler.
 *
 * Yanlışlıkla onaylanan bir fiş için tek çare "hepsini sil" olmamalı.
 * Satırlar ve fiyat gözlemleri basamaklı gidiyor; türetilmiş tablolar
 * kullanıcıya bağlı olduğu için endeks yeniden hesaplanıyor.
 */
receiptsRouter.delete('/:id', async (req: AuthedRequest, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rowCount } = await client.query(
      `DELETE FROM receipts WHERE id = $1 AND user_id = $2`,
      [req.params.id, req.userId],
    );
    if (!rowCount) {
      await client.query('ROLLBACK');
      res.status(404).json({ error: 'Fiş bulunamadı' });
      return;
    }
    await client.query('SELECT refresh_user_index($1)', [req.userId]);
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

receiptsRouter.delete('/', async (req: AuthedRequest, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Fiş satırları ve fiyat gözlemleri basamaklı olarak gidiyor.
    const { rowCount } = await client.query(
      `DELETE FROM receipts WHERE user_id = $1`,
      [req.userId],
    );

    // Türetilmiş tablolar fişe değil kullanıcıya bağlı; basamak onları
    // götürmüyor, tek tek boşaltılıyorlar.
    for (const table of [
      'monthly_product_prices',
      'basket_weights',
      'index_levels',
    ]) {
      await client.query(`DELETE FROM ${table} WHERE user_id = $1`, [
        req.userId,
      ]);
    }

    await client.query('COMMIT');
    res.json({ ok: true, deletedReceipts: rowCount ?? 0 });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});
