/**
 * EVDS sözleşmesi belgelenmemiş; bu testler onu koda sabitliyor.
 *
 * Ağa çıkılmıyor: gerçek anahtar CI'da yok ve TCMB'yi her koşuda yormanın
 * anlamı da yok. Sahte cevap, gerçek API'den birebir alınmış biçimde.
 */
import { describe, expect, it } from 'vitest';
import { CPI_SERIES, fetchLevels, yearlyChanges } from '../src/official/evds.js';

/** Gerçek EVDS cevabından kopyalanmış biçim. */
const gercekCevap = {
  totalCount: 3,
  items: [
    { Tarih: '06-2025', TP_FE25_OKTG01: '98.40', UNIXTIME: { $numberLong: '1' } },
    { Tarih: '07-2025', TP_FE25_OKTG01: '100.42', UNIXTIME: { $numberLong: '2' } },
    { Tarih: '07-2026', TP_FE25_OKTG01: '132.31', UNIXTIME: { $numberLong: '3' } },
  ],
};

function sahteFetch(cevap: unknown, ok = true): typeof fetch {
  return (async () =>
    ({
      ok,
      status: ok ? 200 : 500,
      json: async () => cevap,
    }) as Response) as unknown as typeof fetch;
}

describe('EVDS', () => {
  it('gerçek cevap biçimini çözüyor', async () => {
    const levels = await fetchLevels({
      apiKey: 'test',
      fetchImpl: sahteFetch(gercekCevap),
    });

    expect(levels).toEqual([
      { month: '2025-06-01', level: 98.4 },
      { month: '2025-07-01', level: 100.42 },
      { month: '2026-07-01', level: 132.31 },
    ]);
  });

  // Alan adı seri kodundan türüyor: TP.FE25.OKTG01 → TP_FE25_OKTG01.
  // Seri kodu değişirse alan adı da değişir; ikisi birbirine bağlı.
  it('alan adı seri kodundan türüyor', () => {
    expect(CPI_SERIES.replaceAll('.', '_')).toBe('TP_FE25_OKTG01');
  });

  it('boş değerli ayı atlıyor', async () => {
    const levels = await fetchLevels({
      apiKey: 'test',
      fetchImpl: sahteFetch({
        items: [
          { Tarih: '01-2026', TP_FE25_OKTG01: '115.73' },
          { Tarih: '02-2026', TP_FE25_OKTG01: null },
          { Tarih: '03-2026', TP_FE25_OKTG01: '' },
        ],
      }),
    });
    expect(levels).toHaveLength(1);
  });

  it('hata durumunda patlıyor, sessizce boş dönmüyor', async () => {
    await expect(
      fetchLevels({ apiKey: 'test', fetchImpl: sahteFetch({}, false) }),
    ).rejects.toThrow(/EVDS 500/);
  });

  describe('yıllık değişim', () => {
    // Gerçek veriden: 07-2025 = 100.42, 07-2026 = 132.31 → %31,76.
    // Bu sayı TÜİK'in açıkladığıyla aynı.
    it('on iki ay öncesine göre hesaplıyor', () => {
      expect(
        yearlyChanges([
          { month: '2025-07-01', level: 100.42 },
          { month: '2026-07-01', level: 132.31 },
        ]),
      ).toEqual([{ month: '2026-07-01', yoyPct: 31.76 }]);
    });

    // Seviyeden hesaplıyoruz çünkü EVDS'in hazır yıllık serisi taban yılı
    // değişince (2003=100 → 2025=100) kopuyor. Aynı serinin kendi içinde
    // oranlamak taban değişiminden etkilenmiyor.
    it('on iki ay öncesi yoksa ayı atlıyor, uydurmuyor', () => {
      expect(
        yearlyChanges([
          { month: '2026-01-01', level: 115.73 },
          { month: '2026-07-01', level: 132.31 },
        ]),
      ).toEqual([]);
    });

    it('sıfır seviyeye bölmüyor', () => {
      expect(
        yearlyChanges([
          { month: '2025-07-01', level: 0 },
          { month: '2026-07-01', level: 132.31 },
        ]),
      ).toEqual([]);
    });
  });
});
