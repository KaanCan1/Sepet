import { afterAll, describe, expect, it } from 'vitest';
import { pool, query } from '../src/db.js';
import {
  addProduct,
  addReceipt,
  cleanup,
  refresh,
  startScenario,
  type Scenario,
} from './fixtures/scenario.js';

afterAll(async () => {
  // Senaryo temizliği testin sonunda çağrılıyor; test yarıda düşerse
  // çalışmıyor ve referans katalogda artık kalıyordu. Koşu sonunda garanti.
  await query(
    `DELETE FROM canonical_products
      WHERE category_id = (SELECT id FROM categories WHERE code = 'TEST')`,
  );
  await query(`DELETE FROM categories WHERE code = 'TEST'`);
  await pool.end();
});

/** Bir kullanıcının endeks serisini ay -> seviye olarak döndürür. */
async function levels(s: Scenario) {
  const rows = await query<{ month: Date; level: number; covered_weight: number }>(
    `SELECT month, level, covered_weight FROM index_levels
      WHERE user_id = $1 ORDER BY month`,
    [s.userId],
  );
  return rows.map((r) => ({
    month: r.month.toISOString().slice(0, 10),
    level: r.level,
    covered: r.covered_weight,
  }));
}

describe('Laspeyres endeksi', () => {
  /**
   * ALTIN VERİ SETİ — kâğıt üzerinde hesaplanabilir senaryo.
   *
   * İki ürün, üç ay. Beklenen değerler elle çıkarıldı; bu test kırılırsa
   * formül bozulmuş demektir.
   *
   *  Ay 1: Süt 40,00 TL/L (80 TL harcama)   Yumurta 4,00 TL/adet (120 TL)
   *  Ay 2: Süt 50,00 TL/L (100 TL)          Yumurta 4,40 TL/adet (132 TL)
   *  Ay 3: Süt 55,00 TL/L (110 TL)          Yumurta 4,40 TL/adet (132 TL)
   *
   * Ağırlıklar cari ayı DIŞARIDA bırakır:
   *  Ay 2 penceresi = {Ay 1}      -> süt 80/200 = 0,40   yumurta 0,60
   *  Ay 3 penceresi = {Ay 1, Ay 2} -> süt 180/432 = 0,41666…  yumurta 0,58333…
   *
   * Halkalar:
   *  L2 = 0,40·(50/40) + 0,60·(4,4/4)   = 0,50000 + 0,66000 = 1,16000
   *  L3 = 0,41666·(55/50) + 0,58333·1,0 = 0,45833 + 0,58333 = 1,04166…
   *
   * Seviyeler: 100 -> 116,000 -> 120,8333…
   * 12 aylık pencere dolmadığı için manşet 2 aylık: %20,8
   */
  it('elle hesaplanan senaryoyla birebir örtüşür', async () => {
    const s = await startScenario('altin');
    await addProduct(s, 'sut', {
      name: 'Süt tam yağlı',
      sizeLabel: '1 litre',
      unit: 'litre',
      sizeValue: 1,
    });
    await addProduct(s, 'yumurta', {
      name: 'Yumurta',
      sizeLabel: "30'lu",
      unit: 'adet',
      sizeValue: 30,
    });

    // quantity 2 = iki paket 1 L; birim fiyat tutar/(adet*içerik).
    await addReceipt(s, -2, [
      { product: 'sut', quantity: 2, amount: 80 },
      { product: 'yumurta', amount: 120 },
    ]);
    await addReceipt(s, -1, [
      { product: 'sut', quantity: 2, amount: 100 },
      { product: 'yumurta', amount: 132 },
    ]);
    await addReceipt(s, 0, [
      { product: 'sut', quantity: 2, amount: 110 },
      { product: 'yumurta', amount: 132 },
    ]);
    await refresh(s);

    const l = await levels(s);
    expect(l).toHaveLength(3);
    expect(l[0]!.level).toBeCloseTo(100, 4);
    expect(l[1]!.level).toBeCloseTo(116, 4);
    expect(l[2]!.level).toBeCloseTo(120.833333, 4);

    // Her iki ürün de her iki ayda mevcut: kapsam tam.
    expect(l[1]!.covered).toBeCloseTo(1, 6);
    expect(l[2]!.covered).toBeCloseTo(1, 6);

    const [head] = await query<{
      change_pct: number;
      window_months: number;
    }>(`SELECT change_pct, window_months FROM v_index_headline WHERE user_id = $1`, [
      s.userId,
    ]);
    expect(head!.change_pct).toBeCloseTo(20.8, 6);
    // 12 ay dolmadı: yıllıklandırma yok, gerçek pencere dönüyor.
    expect(head!.window_months).toBe(2);

    await cleanup(s);
  });

  it('birim fiyat paket boyutundan bağımsız', async () => {
    const s = await startScenario('birim');
    await addProduct(s, 'sut1', {
      name: 'Süt',
      sizeLabel: '1 litre',
      unit: 'litre',
      sizeValue: 1,
    });
    await addProduct(s, 'sut3', {
      name: 'Süt büyük',
      sizeLabel: '3 litre',
      unit: 'litre',
      sizeValue: 3,
    });
    await addProduct(s, 'y30', {
      name: 'Yumurta',
      sizeLabel: "30'lu",
      unit: 'adet',
      sizeValue: 30,
    });
    await addProduct(s, 'y15', {
      name: 'Yumurta küçük',
      sizeLabel: "15'li",
      unit: 'adet',
      sizeValue: 15,
    });

    await addReceipt(s, 0, [
      // 1 L'den 3 adet, 120 TL -> 40 TL/L
      { product: 'sut1', quantity: 3, amount: 120 },
      // 3 L'den 1 adet, 120 TL -> 40 TL/L. Aynı birim fiyat.
      { product: 'sut3', quantity: 1, amount: 120 },
      // 30'lu 184,50 -> 6,15 TL/adet
      { product: 'y30', amount: 184.5 },
      // 15'li 92,25 -> 6,15 TL/adet
      { product: 'y15', amount: 92.25 },
    ]);

    // Sıralamaya güvenmek yerine ürün bazında oku.
    const priceOf = async (key: string) => {
      const [row] = await query<{ unit_price: number; pack_price: number }>(
        `SELECT unit_price, pack_price FROM price_observations
          WHERE user_id = $1 AND canonical_product_id = $2`,
        [s.userId, s.products[key]],
      );
      return row!;
    };

    // Paket boyutu ne olursa olsun birim fiyat aynı.
    expect((await priceOf('sut1')).unit_price).toBeCloseTo(40, 6);
    expect((await priceOf('sut3')).unit_price).toBeCloseTo(40, 6);
    expect((await priceOf('y30')).unit_price).toBeCloseTo(6.15, 6);
    expect((await priceOf('y15')).unit_price).toBeCloseTo(6.15, 6);

    // Ekran 03 paket fiyatını gösteriyor; o ayrı tutuluyor ve farklı.
    expect((await priceOf('sut1')).pack_price).toBeCloseTo(40, 2);
    expect((await priceOf('sut3')).pack_price).toBeCloseTo(120, 2);

    await cleanup(s);
  });

  it('gözlemsiz ay fiyatı taşır, değişime katkı vermez', async () => {
    const s = await startScenario('bosluk');
    await addProduct(s, 'yag', {
      name: 'Ayçiçek yağı',
      sizeLabel: '5 litre',
      unit: 'litre',
      sizeValue: 5,
    });
    // Ortadaki ay boş.
    await addReceipt(s, -2, [{ product: 'yag', amount: 250 }]);
    await addReceipt(s, 0, [{ product: 'yag', amount: 300 }]);
    await refresh(s);

    const rows = await query<{ is_imputed: boolean; unit_price: number }>(
      `SELECT is_imputed, unit_price FROM monthly_product_prices
        WHERE user_id = $1 ORDER BY month`,
      [s.userId],
    );
    expect(rows).toHaveLength(3);
    expect(rows[1]!.is_imputed).toBe(true);
    // Taşınan fiyat öncekiyle aynı -> oran 1,0.
    expect(rows[1]!.unit_price).toBeCloseTo(rows[0]!.unit_price, 6);

    const l = await levels(s);
    expect(l[1]!.level).toBeCloseTo(100, 6); // boş ayda değişim yok
    expect(l[2]!.level).toBeCloseTo(120, 6); // 300/250 = 1,2

    await cleanup(s);
  });

  it('bayatlayan ürün sepetten düşer', async () => {
    const s = await startScenario('bayat');
    await addProduct(s, 'cay', {
      name: 'Çay',
      sizeLabel: '1 kg',
      unit: 'kilogram',
      sizeValue: 1,
    });
    // Tek gözlem, 8 ay önce. Bayatlık sınırı 6 ay.
    await addReceipt(s, -8, [{ product: 'cay', amount: 200 }]);
    await refresh(s);

    const months = await query<{ month: Date }>(
      `SELECT month FROM monthly_product_prices WHERE user_id = $1 ORDER BY month`,
      [s.userId],
    );
    // 8 ay önceki gözlemden itibaren 6 ay taşınır, sonrası üretilmez.
    expect(months).toHaveLength(7); // gözlem ayı + 6 taşıma
    await cleanup(s);
  });

  it('virgülü kaymış satır elenir, endeksi bozmaz', async () => {
    const s = await startScenario('aykiri');
    await addProduct(s, 'peynir', {
      name: 'Beyaz peynir',
      sizeLabel: '600 g',
      unit: 'kilogram',
      sizeValue: 0.6,
    });

    await addReceipt(s, -2, [{ product: 'peynir', amount: 120 }]);
    await addReceipt(s, -1, [{ product: 'peynir', amount: 132 }]);
    // OCR virgülü kaydırdı: 138,60 yerine 13860.
    await addReceipt(s, 0, [{ product: 'peynir', amount: 13860 }], 3);
    await addReceipt(s, 0, [{ product: 'peynir', amount: 138.6 }], 20);
    await refresh(s);

    const flagged = await query<{ amount: number; is_outlier: boolean }>(
      `SELECT amount, is_outlier FROM price_observations
        WHERE user_id = $1 ORDER BY amount DESC`,
      [s.userId],
    );
    expect(flagged[0]!.amount).toBe(13860);
    expect(flagged[0]!.is_outlier).toBe(true);
    expect(flagged.slice(1).every((r) => !r.is_outlier)).toBe(true);

    // Bozuk satır elendiği için seri düzgün: 120 -> 132 -> 138,60
    const l = await levels(s);
    expect(l[1]!.level).toBeCloseTo(110, 4);
    expect(l[2]!.level).toBeCloseTo(115.5, 4);

    await cleanup(s);
  });

  it('eşleşmemiş satır hesaba girmez, onaylanınca girer', async () => {
    const s = await startScenario('eslesme');
    await addProduct(s, 'ekmek', {
      name: 'Ekmek',
      sizeLabel: '500 g',
      unit: 'kilogram',
      sizeValue: 0.5,
    });
    const receiptId = await addReceipt(
      s,
      0,
      [{ product: 'ekmek', amount: 30, status: 'pending' }],
    );

    let obs = await query(
      `SELECT 1 FROM price_observations WHERE user_id = $1`,
      [s.userId],
    );
    expect(obs).toHaveLength(0);

    await query(
      `UPDATE receipt_lines SET status = 'confirmed' WHERE receipt_id = $1`,
      [receiptId],
    );
    obs = await query(`SELECT 1 FROM price_observations WHERE user_id = $1`, [
      s.userId,
    ]);
    expect(obs).toHaveLength(1);

    await cleanup(s);
  });

  it('boş sepet hata değil, tanımlı sonuç', async () => {
    const s = await startScenario('bos');
    await refresh(s);

    expect(await levels(s)).toHaveLength(0);
    const head = await query(
      `SELECT 1 FROM v_index_headline WHERE user_id = $1`,
      [s.userId],
    );
    expect(head).toHaveLength(0);

    await cleanup(s);
  });

  it('hesap silinince veri gerçekten siliniyor', async () => {
    const s = await startScenario('silme');
    await addProduct(s, 'sut', {
      name: 'Süt',
      sizeLabel: '1 litre',
      unit: 'litre',
      sizeValue: 1,
    });
    await addReceipt(s, 0, [{ product: 'sut', amount: 40 }]);
    await refresh(s);

    await query(`DELETE FROM users WHERE id = $1`, [s.userId]);

    for (const table of [
      'receipts',
      'price_observations',
      'monthly_product_prices',
      'basket_weights',
      'index_levels',
    ]) {
      const rows = await query(
        `SELECT 1 FROM ${table} WHERE user_id = $1`,
        [s.userId],
      );
      expect(rows, `${table} temizlenmeliydi`).toHaveLength(0);
    }

    await query(`DELETE FROM merchants WHERE id = $1`, [s.merchantId]);
  });
});
