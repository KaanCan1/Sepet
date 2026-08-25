import { afterAll, describe, expect, it } from 'vitest';
import { pool } from '../src/db.js';
import { matchCatalog } from '../src/catalog-match.js';
import { MATCH_CASES, NEGATIVE_CASES } from './fixtures/match-eval.js';

afterAll(async () => {
  await pool.end();
});

/**
 * Eşleştirme kalitesinin tabanı.
 *
 * Eşikler ve puanlama ağırlıkları ölçüyle seçildi (scripts/match-eval.ts).
 * Bu test o ölçümü sabitliyor: katalog büyüdükçe ya da puanlama
 * değiştikçe kalite sessizce geri gitmesin.
 *
 * İki sayı arasındaki fark önemli. Kullanıcıya soran bir sistem YAVAŞTIR;
 * yanlış bağlayan bir sistem BOZUKTUR — endeks birim fiyattan
 * hesaplandığı için yanlış eşleşme sessizce yanlış enflasyon üretiyor.
 * O yüzden hata sayısı kesin sıfır, doğru sayısı ise bir taban.
 */
describe('Eşleştirme kalitesi', () => {
  it('etiketli kümede hiç yanlış bağlama yok', async () => {
    const yanlis: string[] = [];
    for (const v of MATCH_CASES) {
      const o = await matchCatalog(v.raw, 6);
      if (!o.auto) continue;
      const dogru =
        o.auto.groupName === v.group &&
        (o.auto.brandName ?? null) === v.brand &&
        o.auto.sizeLabel === v.size;
      if (!dogru) {
        yanlis.push(
          `${v.raw} -> ${o.auto.displayName} ` +
            `(olmalıydı: ${v.brand ?? '(markasız)'} ${v.group} ${v.size})`,
        );
      }
    }
    expect(yanlis).toEqual([]);
  });

  it('otomatik eşleşme oranı tabanın altına düşmüyor', async () => {
    let dogru = 0;
    for (const v of MATCH_CASES) {
      const o = await matchCatalog(v.raw, 6);
      if (
        o.auto &&
        o.auto.groupName === v.group &&
        (o.auto.brandName ?? null) === v.brand &&
        o.auto.sizeLabel === v.size
      ) {
        dogru++;
      }
    }
    // Ölçülen: 40'ta 35 (%87,5). Taban biraz altında — katalog büyüdükçe
    // bir iki vaka yer değiştirebilir ve testin kırılganlık nöbeti
    // geçirmesi istenmiyor. Ama 33'ün altı gerileme demek.
    expect(dogru).toBeGreaterThanOrEqual(33);
  });

  it('katalogda olmayan ürün otomatik bağlanmıyor', async () => {
    // Vakalar kasıtlı olarak düşmanca: her biri katalogdaki bir marka ya
    // da grupla çakışıyor. "LAYS PATATES CIPSI" bir zamanlar 0,811 puanla
    // "Patates kilogram"a bağlanacak kadar yakındı.
    const bagli: string[] = [];
    for (const raw of NEGATIVE_CASES) {
      const o = await matchCatalog(raw, 6);
      if (o.auto) bagli.push(`${raw} -> ${o.auto.displayName}`);
    }
    expect(bagli).toEqual([]);
  });

  it('boy fişte yazmıyorsa soruluyor', async () => {
    // Paketli üründe boy tahmin edilemez: 1 kg ile 3 kg yoğurdun kilo
    // fiyatı üç kat farklı ve fark doğrudan endekse giriyor.
    const o = await matchCatalog('TAM BUGDAY EKMEK', 6);
    expect(o.sizeAmbiguous).toBe(true);
    expect(o.auto).toBeNull();
  });
});
