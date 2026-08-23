import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { pool, query } from '../db.js';

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
      const productId = line.canonicalProductId ?? alias[0]?.canonical_product_id ?? null;

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
          productId ? 'auto' : 'pending',
          productId && alias[0] ? 1 : null,
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
