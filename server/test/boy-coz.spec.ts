import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pool, query } from '../src/db.js';
import { boyCoz } from '../src/reference/boy-coz.js';
import { canonicalId } from './fixtures/catalog-ref.js';

/**
 * Fiyattan boy çözme.
 *
 * Bu testlerin asıl işi doğru cevabı doğrulamak DEĞİL — yanlış cevabı
 * engellemek. Yanlış boy, endeksi birim fiyattan hesapladığımız için sessizce
 * yanlış enflasyon üretiyor: 500 g yerine 1 kg seçilirse birim fiyat yarıya
 * iner ve o ürün "ucuzladı" görünür. Kullanıcıya sormak yavaştır; yanlış
 * bağlamak bozuktur.
 *
 * Bu yüzden aşağıdaki dört olumsuz vaka, tek olumlu vakadan daha önemli.
 */

const ZINCIR = 'BOYCOZ-TEST';
const TARIH = '2026-08-24';

let merchantId: string;
let bir: string;
let birBucuk: string;

async function referans(
  urunId: string,
  fiyat: number,
  gun: string,
  ref: string,
  baslik: string,
): Promise<void> {
  await query(
    `INSERT INTO reference_prices
       (canonical_product_id, merchant_id, observed_on, price,
        source, source_ref, source_title)
     VALUES ($1, $2, $3::date, $4, 'test', $5, $6)`,
    [urunId, merchantId, gun, fiyat, ref, baslik],
  );
}

beforeAll(async () => {
  const [m] = await query<{ id: string }>(
    `INSERT INTO merchants (name, chain_code) VALUES ('Boy testi', $1)
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
});

afterAll(async () => {
  await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
    merchantId,
  ]);
  await query(`DELETE FROM merchants WHERE chain_code = $1`, [ZINCIR]);
  await pool.end();
});

describe('Fiyattan boy çözme', () => {
  it('kuruşu kuruşuna tutan tek boyu seçiyor', async () => {
    await referans(bir, 99.5, TARIH, 'a', 'Sütaş Yoğurt 1 Kg');
    await referans(birBucuk, 127.5, TARIH, 'b', 'Sütaş Yoğurt 1.5 Kg');

    const sonuc = await boyCoz({
      adayIds: [bir, birBucuk],
      birimFiyat: 127.5,
      merchantId,
      tarih: TARIH,
    });

    expect(sonuc.cozuldu).toBe(true);
    if (sonuc.cozuldu) {
      expect(sonuc.kanit.canonicalProductId).toBe(birBucuk);
      // Kanıt, kullanıcıya gösterilebilecek kadar somut olmalı.
      expect(sonuc.kanit.sourceTitle).toBe('Sütaş Yoğurt 1.5 Kg');
      expect(sonuc.kanit.price).toBe(127.5);
    }

    await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
      merchantId,
    ]);
  });

  it('beş kuruş bile tutmuyorsa çözmüyor', async () => {
    await referans(bir, 99.5, TARIH, 'a', 'Sütaş Yoğurt 1 Kg');
    await referans(birBucuk, 127.5, TARIH, 'b', 'Sütaş Yoğurt 1.5 Kg');

    // 127,45 ile 127,50 farklı iki üründür. Yaklaşık eşleşmeye izin vermek,
    // promosyonlu bir başka boya denk gelme riskini açardı.
    const sonuc = await boyCoz({
      adayIds: [bir, birBucuk],
      birimFiyat: 127.45,
      merchantId,
      tarih: TARIH,
    });

    expect(sonuc).toEqual({ cozuldu: false, sebep: 'fiyat-tutmadi' });

    await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
      merchantId,
    ]);
  });

  it('iki boy aynı fiyattaysa çözmüyor', async () => {
    // Fiyat o soruyu cevaplamıyor demektir. Birini seçmek yazı tura atmak
    // olurdu ve tura gelirse endeks sessizce bozulurdu.
    await referans(bir, 110.0, TARIH, 'a', 'Sütaş Yoğurt 1 Kg');
    await referans(birBucuk, 110.0, TARIH, 'b', 'Sütaş Yoğurt 1.5 Kg');

    const sonuc = await boyCoz({
      adayIds: [bir, birBucuk],
      birimFiyat: 110.0,
      merchantId,
      tarih: TARIH,
    });

    expect(sonuc).toEqual({ cozuldu: false, sebep: 'birden-cok-boy' });

    await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
      merchantId,
    ]);
  });

  it('referans penceresi dışındaysa çözmüyor', async () => {
    // Üç ay önceki fiyat bugünkü fişi çözemez: aradaki zamda o fiyat başka
    // bir boya kaymış olabilir.
    await referans(birBucuk, 127.5, '2026-05-01', 'b', 'Sütaş Yoğurt 1.5 Kg');

    const sonuc = await boyCoz({
      adayIds: [bir, birBucuk],
      birimFiyat: 127.5,
      merchantId,
      tarih: TARIH,
    });

    expect(sonuc).toEqual({ cozuldu: false, sebep: 'referans-yok' });

    await query(`DELETE FROM reference_prices WHERE merchant_id = $1`, [
      merchantId,
    ]);
  });

  it('başka zincirin fiyatıyla çözmüyor', async () => {
    // A101'in fiyatı Migros fişindeki satırı çözemez.
    const [baska] = await query<{ id: string }>(
      `SELECT id FROM merchants WHERE chain_code = 'MIGROS'`,
    );
    await query(
      `INSERT INTO reference_prices
         (canonical_product_id, merchant_id, observed_on, price,
          source, source_ref, source_title)
       VALUES ($1, $2, $3::date, 127.5, 'test', 'x', 'Sütaş Yoğurt 1.5 Kg')
       ON CONFLICT DO NOTHING`,
      [birBucuk, baska!.id, TARIH],
    );

    const sonuc = await boyCoz({
      adayIds: [bir, birBucuk],
      birimFiyat: 127.5,
      merchantId,
      tarih: TARIH,
    });

    expect(sonuc.cozuldu).toBe(false);

    await query(
      `DELETE FROM reference_prices
        WHERE merchant_id = $1 AND source = 'test'`,
      [baska!.id],
    );
  });
});
