import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { pool, query } from '../src/db.js';
import { canonicalId } from './fixtures/catalog-ref.js';

/**
 * Fiş kaydında boyun fiyattan çözülmesi — uçtan uca.
 *
 * `boy-coz.spec.ts` çözücünün kendisini ölçüyor. Burası akışı ölçüyor:
 * fiş POST edildiğinde satır gerçekten `auto` oluyor mu, kanıt gerçekten
 * saklanıyor mu, ve kanıt fiş detayında istemciye gidiyor mu.
 *
 * Kanıtın istemciye gitmesi bir ayrıntı değil ürünün kuralı: ekranda bir
 * gramaj belirip nereden geldiği söylenmezse, "gramaj asla tahmin edilmez"
 * kuralı teknik olarak korunmuş ama kullanıcı açısından bozulmuş olur.
 */

const app = createApp();
const ZINCIR = 'BOYKANIT-TEST';
const TARIH = '2026-08-24';

let token = '';
let merchantId = '';
let birBucuk = '';
let bir = '';

const auth = () => ({ Authorization: `Bearer ${token}` });

beforeAll(async () => {
  const res = await request(app)
    .post('/auth/dev-login')
    .send({ email: `boykanit-${Date.now()}@sepet.app` });
  token = res.body.token;

  const [m] = await query<{ id: string }>(
    `INSERT INTO merchants (name, chain_code) VALUES ('Kanıt testi', $1)
     ON CONFLICT (chain_code) DO UPDATE SET name = EXCLUDED.name
     RETURNING id`,
    [ZINCIR],
  );
  merchantId = m!.id;

  bir = await canonicalId('Yoğurt', 'Sütaş', '1 kg');
  birBucuk = await canonicalId('Yoğurt', 'Sütaş', '1,5 kg');

  await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
    merchantId,
  ]);
  for (const [id, fiyat, ref, baslik] of [
    [bir, 99.5, 'a', 'Sütaş Yoğurt 1 Kg'],
    [birBucuk, 127.5, 'b', 'Sütaş Yoğurt 1.5 Kg'],
  ] as const) {
    await query(
      `INSERT INTO reference_prices
         (canonical_product_id, merchant_id, observed_on, price,
          source, source_ref, source_title)
       VALUES ($1, $2, $3::date, $4, 'test', $5, $6)`,
      [id, merchantId, TARIH, fiyat, ref, baslik],
    );
  }
});

afterAll(async () => {
  await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
    merchantId,
  ]);
  await pool.end();
});

/** Boy yazmayan, kısaltılmış bir yazarkasa satırı — gerçek fişlerdeki hâli. */
const HAM = 'SUTAS T.YAGLI YOGU.';

describe('Fiş kaydında fiyattan boy çözme', () => {
  it('fiyat tutunca satır auto oluyor ve kanıt saklanıyor', async () => {
    const post = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: TARIH,
        lines: [{ raw: HAM, quantity: 1, amount: 127.5 }],
      })
      .expect(201);

    const detay = await request(app)
      .get(`/receipts/${post.body.id}`)
      .set(auth())
      .expect(200);

    const satir = detay.body.lines[0];
    expect(satir.status).toBe('auto');
    expect(satir.canonical).toContain('1,5 kg');
    // Kanıt istemciye gidiyor ve gösterilecek kadar somut.
    expect(satir.evidence).toMatchObject({
      sourceTitle: 'Sütaş Yoğurt 1.5 Kg',
      price: 127.5,
      observedOn: TARIH,
    });
  });

  it('fiyat tutmayınca eskisi gibi kullanıcıya soruluyor', async () => {
    // Aynı satır, tutmayan bir tutarla. Referans yokmuş gibi davranmalı:
    // yanlış boy seçmektense sormak.
    const post = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: TARIH,
        lines: [{ raw: HAM, quantity: 1, amount: 133.9 }],
      })
      .expect(201);

    const detay = await request(app)
      .get(`/receipts/${post.body.id}`)
      .set(auth())
      .expect(200);

    const satir = detay.body.lines[0];
    expect(satir.status).toBe('pending');
    expect(satir.canonical).toBeNull();
    expect(satir.evidence).toBeNull();
  });

  it('miktar birden büyükse birim fiyata bakıyor', async () => {
    // Fişte "2 X 127,50 = 255,00" yazıyor. Referans birim fiyatı yayımlıyor,
    // satır tutarını değil.
    const post = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: TARIH,
        lines: [{ raw: HAM, quantity: 2, amount: 255 }],
      })
      .expect(201);

    const detay = await request(app)
      .get(`/receipts/${post.body.id}`)
      .set(auth())
      .expect(200);

    expect(detay.body.lines[0].status).toBe('auto');
    expect(detay.body.lines[0].canonical).toContain('1,5 kg');
  });

  it('kanıtla gelmeyen eşleşmelerde kanıt boş kalıyor', async () => {
    // Boy fişte yazıyorsa çözücüye hiç gidilmiyor; kanıt da yok.
    const post = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: TARIH,
        lines: [{ raw: 'SUTAS YOGURT 1.5KG', quantity: 1, amount: 127.5 }],
      })
      .expect(201);

    const detay = await request(app)
      .get(`/receipts/${post.body.id}`)
      .set(auth())
      .expect(200);

    expect(detay.body.lines[0].status).toBe('auto');
    expect(detay.body.lines[0].evidence).toBeNull();
  });
});
