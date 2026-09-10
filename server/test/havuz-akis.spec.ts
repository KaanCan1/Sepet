import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { pool, query } from '../src/db.js';
import { canonicalId } from './fixtures/catalog-ref.js';

/**
 * Havuzun fiş akışına bağlanması.
 *
 * Üç durum var ve üçünün AYRI kalması ürünün kuralı:
 *
 *   auto        sepette karşılığı var, endekse giriyor
 *   off_basket  ürün tanındı, sepette yok — sorulmuyor
 *   pending     gerçekten bilinmiyor, soruluyor
 *
 * En kritik bekleyiş sondaki: havuzdan gelen bir kalem sepete SIZMAMALI.
 * Sızsaydı Laspeyres'in sabit ve ağırlıklı sepeti elli bin kalemle şişer,
 * basket_weights anlamını kaybederdi.
 */

const app = createApp();
const ZINCIR = 'HAVUZAKIS-TEST';
const KAYNAK = 'test-akis';

let token = '';
let merchantId = '';

const auth = () => ({ Authorization: `Bearer ${token}` });

beforeAll(async () => {
  const res = await request(app)
    .post('/auth/dev-login')
    .send({ email: `havuzakis-${Date.now()}@sepet.app` });
  token = res.body.token;

  const [m] = await query<{ id: string }>(
    `INSERT INTO merchants (name, chain_code) VALUES ('Havuz akış', $1)
     ON CONFLICT (chain_code) DO UPDATE SET name = EXCLUDED.name RETURNING id`,
    [ZINCIR],
  );
  merchantId = m!.id;

  const sepetteki = await canonicalId('Yoğurt', 'Sütaş', '1 kg');

  await query(`DELETE FROM pool_products WHERE source = $1`, [KAYNAK]);
  // Sepete BAĞLI havuz kalemi.
  await query(
    `INSERT INTO pool_products
       (source, source_ref, title, brand_text, size_value, unit,
        canonical_product_id)
     VALUES ($1, 'a', 'Testaş Zurna 1 Kg', 'Testaş', 1, 'kilogram', $2)`,
    [KAYNAK, sepetteki],
  );
  // Sepete bağlı OLMAYAN havuz kalemi — gerçek ürün, sepetin dışında.
  await query(
    `INSERT INTO pool_products
       (source, source_ref, title, brand_text, size_value, unit)
     VALUES ($1, 'b', 'Vivaş Borazan 6 Adet', 'Vivaş', 6, 'adet')`,
    [KAYNAK],
  );
});

afterAll(async () => {
  await query(`DELETE FROM pool_products WHERE source = $1`, [KAYNAK]);
  await pool.end();
});

async function satirlar(lines: { raw: string; amount: number }[]) {
  const post = await request(app)
    .post('/receipts')
    .set(auth())
    .send({ merchantId, purchasedAt: '2026-09-10', lines })
    .expect(201);
  const detay = await request(app)
    .get(`/receipts/${post.body.id}`)
    .set(auth())
    .expect(200);
  return detay.body.lines;
}

describe('Havuz fiş akışında', () => {
  it('sepete bağlı havuz kalemi endekse giriyor', async () => {
    const [l] = await satirlar([{ raw: 'TESTAS ZURNA 1KG', amount: 99.5 }]);
    expect(l.status).toBe('auto');
    expect(l.canonical).toContain('1 kg');
  });

  it('sepet dışı ürün tanınıyor ama sorulmuyor', async () => {
    const [l] = await satirlar([{ raw: 'VIVAS BORAZAN 6LI', amount: 89.95 }]);
    expect(l.status).toBe('off_basket');
    // Ad havuzdan geliyor: kullanıcı ham fiş metnini değil ürünü görüyor.
    expect(l.poolTitle).toBe('Vivaş Borazan 6 Adet');
    // Ama endekse girmiyor: kanonik karşılığı yok.
    expect(l.canonical).toBeNull();
  });

  it('sepet dışı satır SEPETE SIZMIYOR', async () => {
    // Bu testin tek işi bu. Havuz serbest büyüyor, sepet büyümüyor.
    const [l] = await satirlar([{ raw: 'VIVAS BORAZAN 6LI', amount: 89.95 }]);
    const [{ n }] = await query<{ n: string }>(
      `SELECT count(*)::text AS n FROM price_observations WHERE receipt_line_id = $1`,
      [l.id],
    );
    expect(Number(n)).toBe(0);
  });

  it('havuzda da olmayan satır eskisi gibi soruluyor', async () => {
    const [l] = await satirlar([{ raw: 'BILINMEYEN SEY', amount: 10 }]);
    expect(l.status).toBe('pending');
  });

  it('sepet dışı satırlar bekleyen sayısına girmiyor', async () => {
    // "3 kalem eşleşme bekliyor" derken kastedilen, kullanıcının
    // cevaplayabileceği satırlar. Cevabı olmayan bir soruyu saymak
    // kullanıcıyı bitmeyen bir işe davet etmek olurdu.
    await satirlar([{ raw: 'VIVAS BORAZAN 6LI', amount: 89.95 }]);
    const liste = await request(app).get('/receipts').set(auth()).expect(200);
    const sonFis = liste.body[0];
    expect(sonFis.pendingCount).toBe(0);
  });
});
