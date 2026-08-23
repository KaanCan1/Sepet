/**
 * Katalog yüklemesinin iki özelliği: tekrar çalıştırılabilir olması ve
 * kullanıcı verisine bağlı satırlara asla dokunmaması.
 *
 * İkincisi ciddi. Katalog her dağıtımda yeniden yükleniyor ve marka öncesi
 * artıkları siliyor; koşul gevşerse kullanıcının eşleştirdiği ürünler
 * sessizce silinir, fiş satırları eşleşmesiz kalır ve endeks bozulur.
 */
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { one, pool, query } from '../src/db.js';

const here = dirname(fileURLToPath(import.meta.url));
const catalogSql = () =>
  readFile(join(here, '..', 'seeds', 'catalog.sql'), 'utf8');

describe('Referans katalog', () => {
  let legacyId: string;
  let merchantId: string;

  beforeAll(async () => {
    // Marka öncesi dönemden kalmış bir satırı taklit et: markalı ürünleri
    // olan bir grupta, katalogun saymadığı bir boyda, markasız.
    const group = await one<{ id: string }>(
      `SELECT g.id FROM product_groups g
        WHERE EXISTS (SELECT 1 FROM canonical_products cp
                       WHERE cp.group_id = g.id AND cp.brand_id IS NOT NULL)
        LIMIT 1`,
    );
    const legacy = await one<{ id: string }>(
      `INSERT INTO canonical_products (group_id, brand_id, size_label, size_value)
       VALUES ($1, NULL, 'eski 7 birim', 7) RETURNING id`,
      [group.id],
    );
    legacyId = legacy.id;

    const merchant = await one<{ id: string }>(
      `SELECT id FROM merchants LIMIT 1`,
    );
    merchantId = merchant.id;
  });

  afterAll(async () => {
    await query(`DELETE FROM product_aliases WHERE canonical_product_id = $1`, [
      legacyId,
    ]);
    await query(`DELETE FROM canonical_products WHERE id = $1`, [legacyId]);
    await pool.end();
  });

  it('bağsız artık satırı temizliyor', async () => {
    await pool.query(await catalogSql());

    const rows = await query(
      `SELECT id FROM canonical_products WHERE id = $1`,
      [legacyId],
    );
    expect(rows, 'hiçbir yere bağlı olmayan artık silinmeliydi').toHaveLength(0);
  });

  it('kullanıcı verisine bağlı satıra dokunmuyor', async () => {
    // Satırı geri koy, bu sefer öğrenilmiş bir eşleşmeyle birlikte.
    await query(
      `INSERT INTO canonical_products (id, group_id, brand_id, size_label, size_value)
       SELECT $1, g.id, NULL, 'eski 7 birim', 7 FROM product_groups g
        WHERE EXISTS (SELECT 1 FROM canonical_products cp
                       WHERE cp.group_id = g.id AND cp.brand_id IS NOT NULL)
        LIMIT 1`,
      [legacyId],
    );
    await query(
      `INSERT INTO product_aliases (merchant_id, raw_text_normalized, canonical_product_id)
       VALUES ($1, normalize_raw_text('ESKI URUN 7'), $2)`,
      [merchantId, legacyId],
    );

    await pool.query(await catalogSql());

    const rows = await query(
      `SELECT id FROM canonical_products WHERE id = $1`,
      [legacyId],
    );
    expect(rows, 'eşleşmesi olan satır silinmemeliydi').toHaveLength(1);
  });

  it('tekrar çalıştırınca ürün sayısı değişmiyor', async () => {
    const before = await one<{ n: number }>(
      `SELECT count(*)::int AS n FROM canonical_products`,
    );
    await pool.query(await catalogSql());
    const after = await one<{ n: number }>(
      `SELECT count(*)::int AS n FROM canonical_products`,
    );
    expect(after.n).toBe(before.n);
  });
});
