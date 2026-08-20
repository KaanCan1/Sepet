import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { one, pool, query } from '../src/db.js';

const app = createApp();

let token = '';
let userId = '';
let merchantId = '';
let sutId = '';
let yumurtaId = '';
/** Alias tablosu koşular arası kalıcı; her koşu kendi ham metnini kullansın. */
const uniqueRaw = `ZEYTIN YAGI SIZMA ${Date.now()}`;

beforeAll(async () => {
  const email = `api-${Date.now()}@sepet.test`;
  const res = await request(app).post('/auth/dev-login').send({ email });
  token = res.body.token;
  userId = res.body.userId;

  merchantId = (
    await one<{ id: string }>(
      `SELECT id FROM merchants WHERE chain_code = 'BIM'`,
    )
  ).id;
  sutId = (
    await one<{ id: string }>(
      `SELECT id FROM canonical_products WHERE name = 'Süt, tam yağlı'`,
    )
  ).id;
  yumurtaId = (
    await one<{ id: string }>(
      `SELECT id FROM canonical_products WHERE name = 'Yumurta' AND size_label = '30''lu'`,
    )
  ).id;
});

afterAll(async () => {
  if (userId) await query(`DELETE FROM users WHERE id = $1`, [userId]);
  // Test kendi alias izini bırakmasın.
  await query(
    `DELETE FROM product_aliases WHERE raw_text_normalized = normalize_raw_text($1)`,
    [uniqueRaw],
  );
  await pool.end();
});

const auth = () => ({ Authorization: `Bearer ${token}` });

/** Belirtilen ay ofsetinde bir tarih üretir. */
function monthsAgo(n: number, day = 14): string {
  const d = new Date();
  d.setDate(1);
  d.setMonth(d.getMonth() - n);
  d.setDate(day);
  return d.toISOString().slice(0, 10);
}

describe('API', () => {
  it('sağlık ucu ayakta', async () => {
    await request(app).get('/health').expect(200, { ok: true });
  });

  it('oturumsuz istek 401 döner', async () => {
    await request(app).get('/index').expect(401);
    await request(app).get('/receipts').expect(401);
  });

  it('geçersiz token 401 döner', async () => {
    await request(app)
      .get('/index')
      .set({ Authorization: 'Bearer uydurma.token.degeri' })
      .expect(401);
  });

  it('boş hesapta endeks null döner, hata değil', async () => {
    const res = await request(app).get('/index').set(auth()).expect(200);
    expect(res.body.headline).toBeNull();
    expect(res.body.series).toEqual([]);
  });

  it('fiş kaydedilir ve endeks anında güncellenir', async () => {
    const first = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(2),
        lines: [
          { raw: 'SUT TAM YAGLI 1L', quantity: 2, amount: 80, canonicalProductId: sutId },
          { raw: 'YUMURTA 30LU', amount: 120, canonicalProductId: yumurtaId },
        ],
      })
      .expect(201);
    expect(first.body.id).toBeTruthy();

    await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(1),
        lines: [
          { raw: 'SUT TAM YAGLI 1L', quantity: 2, amount: 100, canonicalProductId: sutId },
          { raw: 'YUMURTA 30LU', amount: 132, canonicalProductId: yumurtaId },
        ],
      })
      .expect(201);

    const res = await request(app).get('/index').set(auth()).expect(200);
    // Altın senaryodaki ilk halka: %16.
    expect(res.body.headline.changePct).toBeCloseTo(16, 5);
    // Bu ay alışveriş yok; fiyatlar taşınıyor ve seri bu aya kadar uzuyor.
    // Taşınan ayın halkası 1,0 olduğu için seviye 116'da kalıyor.
    expect(res.body.headline.windowMonths).toBe(2);
    expect(res.body.series).toHaveLength(3);
    expect(res.body.series.at(-1).momPct).toBeCloseTo(0, 5);
    // Resmî seriler katalogdan geliyor.
    expect(res.body.official.map((o: { code: string }) => o.code)).toContain(
      'TUIK_TUFE',
    );
  });

  it('eksik alanla fiş reddedilir', async () => {
    await request(app)
      .post('/receipts')
      .set(auth())
      .send({ merchantId })
      .expect(400);
  });

  it('bilinmeyen satır pending kalır, onaylanınca alias yazılır', async () => {
    const created = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(0),
        lines: [{ raw: uniqueRaw, amount: 340 }],
      })
      .expect(201);

    const detail = await request(app)
      .get(`/receipts/${created.body.id}`)
      .set(auth())
      .expect(200);
    expect(detail.body.lines[0].status).toBe('pending');
    expect(detail.body.lines[0].canonical).toBeNull();

    const zeytin = await one<{ id: string }>(
      `SELECT id FROM canonical_products WHERE name = 'Zeytinyağı'`,
    );
    await request(app)
      .post(`/receipts/${created.body.id}/lines/${detail.body.lines[0].id}/match`)
      .set(auth())
      .send({ canonicalProductId: zeytin.id })
      .expect(200);

    // Aynı market + aynı ham metin bir daha sorulmamalı.
    const again = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(0, 25),
        // Küçük harf ve fazladan boşluk: normalize_raw_text ikisini eşitliyor.
        lines: [{ raw: uniqueRaw.toLowerCase().replace(' ', '  '), amount: 355 }],
      })
      .expect(201);

    const secondDetail = await request(app)
      .get(`/receipts/${again.body.id}`)
      .set(auth())
      .expect(200);
    expect(secondDetail.body.lines[0].status).toBe('auto');
    expect(secondDetail.body.lines[0].canonical).toContain('Zeytinyağı');
  });

  it('ürün listesi ve geçmişi döner', async () => {
    const list = await request(app).get('/products').set(auth()).expect(200);
    const sut = list.body.find((p: { id: string }) => p.id === sutId);
    expect(sut).toBeTruthy();
    // 40 -> 50 TL/L
    expect(sut.changePct).toBeCloseTo(25, 5);

    const detail = await request(app)
      .get(`/products/${sutId}`)
      .set(auth())
      .expect(200);
    expect(detail.body.history).toHaveLength(2);
    expect(detail.body.byMerchant[0].merchant).toBe('BİM');
  });

  it('bilinmeyen ürün 404', async () => {
    await request(app)
      .get('/products/00000000-0000-0000-0000-000000000000')
      .set(auth())
      .expect(404);
  });

  it('katalog araması Türkçe karakterden bağımsız', async () => {
    const res = await request(app)
      .get('/products/catalog/search?q=aycicek')
      .set(auth())
      .expect(200);
    expect(res.body.some((p: { name: string }) => p.name === 'Ayçiçek yağı')).toBe(true);
  });

  it('başka kullanıcının fişi görünmez', async () => {
    const other = await request(app)
      .post('/auth/dev-login')
      .send({ email: `other-${Date.now()}@sepet.test` });
    const mine = await request(app).get('/receipts').set(auth()).expect(200);
    const theirs = await request(app)
      .get('/receipts')
      .set({ Authorization: `Bearer ${other.body.token}` })
      .expect(200);

    expect(mine.body.length).toBeGreaterThan(0);
    expect(theirs.body).toHaveLength(0);

    await request(app)
      .get(`/receipts/${mine.body[0].id}`)
      .set({ Authorization: `Bearer ${other.body.token}` })
      .expect(404);

    await query(`DELETE FROM users WHERE id = $1`, [other.body.userId]);
  });
});
