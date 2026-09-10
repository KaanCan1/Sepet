import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { pool, query } from '../src/db.js';
import { refreshReference } from '../src/reference/refresh.js';
import { kaynakBoyuSerbest } from '../src/reference/eslestir.js';

/**
 * Ürün havuzu.
 *
 * Katalog bir ürün listesi değil, bir TÜFE sepeti — doksan altı grup,
 * ağırlıklarıyla. Sepet dışındaki bir fiş satırı hiç eşleşemiyor ve alias da
 * öğrenilemiyordu: gösterilecek bir hedef yoktu.
 *
 * Havuzun işi TANIMAK, sepetin işi ÖLÇMEK. Bu testlerin koruduğu şey ikisinin
 * ayrı kalması: kaynağın gördüğü her kalem havuza giriyor, ama hiçbiri
 * kendiliğinden sepete girmiyor.
 */

/**
 * Süt grubu, Yoğurt değil.
 *
 * `referans-cekim.spec.ts` de aynı günlük tablosuna yazıyor ve Yoğurt'u
 * kullanıyor; ikisi paralel koşunca birbirinin satırlarını sayıyordu.
 * Gruplar ayrı olunca dosyalar da ayrı.
 */
const GRUP = 'Süt, tam yağlı';
const KAYNAK = 'marketfiyati.org.tr';

/** Verilen kalemleri döndüren, ağa çıkmayan kaynak. */
function sahteKaynak(
  items: {
    id: string;
    title: string;
    brand: string | null;
    size: string | null;
    kategori?: string;
  }[],
): typeof fetch {
  return (async () =>
    new Response(
      JSON.stringify({
        content: items.map((i) => ({
          id: i.id,
          title: i.title,
          brand: i.brand,
          refinedVolumeOrWeight: i.size,
          main_category: i.kategori ?? 'Süt',
          productDepotInfoList: [
            {
              price: 99.5,
              marketAdi: 'migros',
              indexTime: '10.09.2026 09:00',
            },
          ],
        })),
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    )) as unknown as typeof fetch;
}

/** Sepette karşılığı OLAN ve OLMAYAN birer kalem. */
const KALEMLER = [
  // Sütaş Süt 1 litre sepette var.
  {
    id: 'test-var',
    title: 'Sütaş Tam Yağlı Süt 1 Lt',
    brand: 'Sütaş',
    size: '1 LT',
  },
  // 750 mL yok — gerçek bir ürün ama sepetin dışında.
  {
    id: 'test-yok',
    title: 'Sütaş Laktozsuz Süt 750 Ml',
    brand: 'Sütaş',
    size: '750 ML',
  },
];

async function temizle(): Promise<void> {
  await query(`DELETE FROM pool_products WHERE source_ref LIKE 'test-%'`);
  await query(
    `DELETE FROM reference_fetch_log
      WHERE fetched_on = current_date AND family LIKE '%' || $1`,
    [GRUP],
  );
  await query(`DELETE FROM reference_prices WHERE source_ref LIKE 'test-%'`);
}

beforeEach(temizle);
afterAll(async () => {
  await temizle();
  await pool.end();
});

async function havuzda(ref: string) {
  const [r] = await query<{
    title: string;
    brand_text: string | null;
    size_value: string | null;
    unit: string | null;
    canonical_product_id: string | null;
    main_category: string | null;
    last_seen_on: string;
  }>(
    `SELECT title, brand_text, size_value::text, unit::text,
            canonical_product_id, main_category, last_seen_on::text
       FROM pool_products WHERE source = $1 AND source_ref = $2`,
    [KAYNAK, ref],
  );
  return r;
}

describe('Ürün havuzu', () => {
  it('kaynağın gördüğü her kalem havuza giriyor', async () => {
    await refreshReference({
      grup: GRUP,
      // Gruptaki bütün aileler: köprünün denenmesi için sahte kaynağın
      // markasıyla aynı ailenin de sorgulanması gerekiyor.
      limit: 10,
      force: true,
      fetchImpl: sahteKaynak(KALEMLER),
      bekleMs: 0,
    });

    // Sepette karşılığı olmayan kalem de havuzda — havuzun bütün varlık
    // sebebi bu satırı tanıyabilmek.
    const yok = await havuzda('test-yok');
    expect(yok).toBeDefined();
    expect(yok!.title).toBe('Sütaş Laktozsuz Süt 750 Ml');
    expect(yok!.brand_text).toBe('Sütaş');
    expect(yok!.main_category).toBe('Süt');
  });

  it('boy kaynaktan okunuyor — fişte yazmasına gerek yok', async () => {
    await refreshReference({
      grup: GRUP,
      // Gruptaki bütün aileler: köprünün denenmesi için sahte kaynağın
      // markasıyla aynı ailenin de sorgulanması gerekiyor.
      limit: 10,
      force: true,
      fetchImpl: sahteKaynak(KALEMLER),
      bekleMs: 0,
    });

    const yok = await havuzda('test-yok');
    expect(Number(yok!.size_value)).toBeCloseTo(0.75, 5);
    expect(yok!.unit).toBe('litre');
  });

  it('sepette karşılığı olan kalem köprüyle bağlanıyor', async () => {
    await refreshReference({
      grup: GRUP,
      // Gruptaki bütün aileler: köprünün denenmesi için sahte kaynağın
      // markasıyla aynı ailenin de sorgulanması gerekiyor.
      limit: 10,
      force: true,
      fetchImpl: sahteKaynak(KALEMLER),
      bekleMs: 0,
    });

    const var_ = await havuzda('test-var');
    expect(var_!.canonical_product_id).not.toBeNull();

    const [k] = await query<{ display_name: string }>(
      `SELECT display_name FROM v_canonical_products WHERE id = $1`,
      [var_!.canonical_product_id],
    );
    expect(k!.display_name).toContain('1 litre');
  });

  it('sepette karşılığı olmayan kalem BAĞLANMIYOR', async () => {
    // Havuz serbest büyüyor, sepet büyümüyor. Elli bin kalemi endekse
    // sokmak Laspeyres'i anlamsızlaştırırdı; sepet ağırlığıyla birlikte
    // elle büyüyor.
    await refreshReference({
      grup: GRUP,
      // Gruptaki bütün aileler: köprünün denenmesi için sahte kaynağın
      // markasıyla aynı ailenin de sorgulanması gerekiyor.
      limit: 10,
      force: true,
      fetchImpl: sahteKaynak(KALEMLER),
      bekleMs: 0,
    });

    const yok = await havuzda('test-yok');
    expect(yok!.canonical_product_id).toBeNull();
  });

  it('aynı ürün yeniden çekilince güncelleniyor, çoğalmıyor', async () => {
    await refreshReference({
      grup: GRUP,
      // Gruptaki bütün aileler: köprünün denenmesi için sahte kaynağın
      // markasıyla aynı ailenin de sorgulanması gerekiyor.
      limit: 10,
      force: true,
      fetchImpl: sahteKaynak(KALEMLER),
      bekleMs: 0,
    });
    await refreshReference({
      grup: GRUP,
      // Gruptaki bütün aileler: köprünün denenmesi için sahte kaynağın
      // markasıyla aynı ailenin de sorgulanması gerekiyor.
      limit: 10,
      force: true,
      fetchImpl: sahteKaynak([
        { ...KALEMLER[1]!, title: 'Sütaş Laktozsuz Süt 750 Ml Yeni Ambalaj' },
      ]),
      bekleMs: 0,
    });

    const [{ n }] = await query<{ n: string }>(
      `SELECT count(*)::text AS n FROM pool_products WHERE source_ref = 'test-yok'`,
    );
    expect(Number(n)).toBe(1);
    const yok = await havuzda('test-yok');
    expect(yok!.title).toBe('Sütaş Laktozsuz Süt 750 Ml Yeni Ambalaj');
  });
});

describe('Kaynaktaki boyun birimi', () => {
  // Havuzdaki kalem henüz hiçbir gruba bağlı değil, yani birim metnin
  // kendisinden çıkarılmak zorunda.
  it('ekten birimi çıkarıyor', () => {
    expect(kaynakBoyuSerbest('400 GR', '')).toEqual({
      deger: 0.4,
      birim: 'kilogram',
    });
    expect(kaynakBoyuSerbest('1 LT', '')).toEqual({
      deger: 1,
      birim: 'litre',
    });
    expect(kaynakBoyuSerbest('200 ML', '')).toEqual({
      deger: 0.2,
      birim: 'litre',
    });
  });

  it('boy alanı boşsa başlıktan okuyor', () => {
    // Gerçek vaka: "Viva Kağıt Havlu 6 Adet" için kaynak boy alanını boş
    // bırakıyor ve sayı yalnızca başlıkta yazıyor.
    expect(kaynakBoyuSerbest(null, 'Viva Kağıt Havlu 6 Adet')).toEqual({
      deger: 6,
      birim: 'adet',
    });
  });

  it('okuyamazsa null — uydurmuyor', () => {
    expect(kaynakBoyuSerbest(null, 'Migros Poşet')).toBeNull();
  });
});
