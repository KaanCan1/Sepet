import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { pool, query } from '../src/db.js';
import { aliasCoz, aliasOyVer, MUTABAKAT_ESIGI } from '../src/alias.js';
import { canonicalId } from './fixtures/catalog-ref.js';

/**
 * Öğrenilmiş eşleşmelerin güveni.
 *
 * Alias bir kullanıcının cevabından doğuyor ama herkesi ilgilendiriyor.
 * Yanlış bir alias SESSİZCE yanlış enflasyon üretiyor: yanlış ürün, yanlış
 * birim fiyat, yanlış endeks — ve satır ekranda "eşleşmiş" görünüyor, yani
 * kullanıcı hatayı göremiyor bile.
 *
 * Bu testlerin çoğu bir şeyin OLMADIĞINI doğruluyor: tek cevabın yayılmaması,
 * anlaşmazlıkta kimsenin kazanmaması.
 */

const ZINCIR = 'ALIASGUVEN-TEST';
const HAM = 'ALIAS GUVEN DENEYI';

let merchantId = '';
let urunA = '';
let urunB = '';
const kullanicilar: string[] = [];

async function hesap(): Promise<string> {
  const [u] = await query<{ id: string }>(
    `INSERT INTO users (email) VALUES ($1) RETURNING id`,
    [`aliasguven-${Date.now()}-${Math.random()}@sepet.app`],
  );
  kullanicilar.push(u!.id);
  return u!.id;
}

async function oyVer(userId: string, urun: string): Promise<void> {
  const client = await pool.connect();
  try {
    await aliasOyVer(client, {
      merchantId,
      raw: HAM,
      userId,
      canonicalProductId: urun,
    });
  } finally {
    client.release();
  }
}

async function coz(userId: string) {
  const client = await pool.connect();
  try {
    return await aliasCoz(client, { merchantId, raw: HAM, userId });
  } finally {
    client.release();
  }
}

/** Paylaşılan (mutabakat) alias. */
async function paylasilan() {
  const [r] = await query<{ canonical_product_id: string; confirmations: number }>(
    `SELECT canonical_product_id, confirmations FROM product_aliases
      WHERE merchant_id = $1 AND raw_text_normalized = normalize_raw_text($2)`,
    [merchantId, HAM],
  );
  return r ?? null;
}

beforeEach(async () => {
  const [m] = await query<{ id: string }>(
    `INSERT INTO merchants (name, chain_code) VALUES ('Alias güven', $1)
     ON CONFLICT (chain_code) DO UPDATE SET name = EXCLUDED.name RETURNING id`,
    [ZINCIR],
  );
  merchantId = m!.id;
  urunA = await canonicalId('Yoğurt', 'Sütaş', '1 kg');
  urunB = await canonicalId('Yoğurt', 'Sütaş', '1,5 kg');

  await query(
    `DELETE FROM alias_votes WHERE merchant_id = $1 AND raw_text_normalized = normalize_raw_text($2)`,
    [merchantId, HAM],
  );
  await query(
    `DELETE FROM product_aliases WHERE merchant_id = $1 AND raw_text_normalized = normalize_raw_text($2)`,
    [merchantId, HAM],
  );
});

afterAll(async () => {
  await query(`DELETE FROM merchants WHERE chain_code = $1`, [ZINCIR]);
  if (kullanicilar.length > 0) {
    await query(`DELETE FROM users WHERE id = ANY($1::uuid[])`, [kullanicilar]);
  }
  await pool.end();
});

describe('Alias güveni', () => {
  it('tek kişinin cevabı herkese yayılmıyor', async () => {
    const a = await hesap();
    await oyVer(a, urunA);

    // Cevap veren kendi cevabını alıyor.
    const kendi = await coz(a);
    expect(kendi).toEqual({ canonicalProductId: urunA, kendi: true });

    // Ama başkası almıyor: tek kişinin cevabı mutabakat değil.
    const b = await hesap();
    expect(await coz(b)).toBeNull();
    expect(await paylasilan()).toBeNull();
  });

  it('iki kişi aynı şeyi derse yayılıyor', async () => {
    const a = await hesap();
    const b = await hesap();
    await oyVer(a, urunA);
    await oyVer(b, urunA);

    const c = await hesap();
    expect(await coz(c)).toEqual({ canonicalProductId: urunA, kendi: false });

    const p = await paylasilan();
    expect(p!.canonical_product_id).toBe(urunA);
    // Sayaç artık gerçekten "kaç kişi bu üründe anlaştı" demek.
    expect(p!.confirmations).toBe(MUTABAKAT_ESIGI);
  });

  it('anlaşmazlıkta kimse kazanmıyor', async () => {
    // Eskiden son cevap sessizce kazanıyordu ve sayaç 2 yazıyordu —
    // olmayan bir mutabakatı iddia ediyordu.
    const a = await hesap();
    const b = await hesap();
    await oyVer(a, urunA);
    await oyVer(b, urunB);

    expect(await paylasilan()).toBeNull();

    // Herkes kendi cevabını almaya devam ediyor.
    expect((await coz(a))!.canonicalProductId).toBe(urunA);
    expect((await coz(b))!.canonicalProductId).toBe(urunB);
    // Üçüncü kişiye soruluyor: dayatılacak bir doğru yok.
    expect(await coz(await hesap())).toBeNull();
  });

  it('çoğunluk oluşunca mutabakat geri geliyor', async () => {
    const a = await hesap();
    const b = await hesap();
    const c = await hesap();
    await oyVer(a, urunA);
    await oyVer(b, urunB);
    expect(await paylasilan()).toBeNull();

    await oyVer(c, urunA);
    const p = await paylasilan();
    expect(p!.canonical_product_id).toBe(urunA);
    expect(p!.confirmations).toBe(2);
  });

  it('aynı kişi iki kez oy verince mutabakat saymıyor', async () => {
    // Aynı kişinin tekrar onaylaması mutabakat değil, tekrar. Eski kod
    // bunu sayaca ekliyordu.
    const a = await hesap();
    await oyVer(a, urunA);
    await oyVer(a, urunA);

    expect(await paylasilan()).toBeNull();
    const [{ n }] = await query<{ n: string }>(
      `SELECT count(*)::text AS n FROM alias_votes
        WHERE merchant_id = $1 AND raw_text_normalized = normalize_raw_text($2)`,
      [merchantId, HAM],
    );
    expect(Number(n)).toBe(1);
  });

  it('fikir değiştirince eski oy kalmıyor', async () => {
    const a = await hesap();
    const b = await hesap();
    await oyVer(a, urunA);
    await oyVer(b, urunA);
    expect((await paylasilan())!.canonical_product_id).toBe(urunA);

    // a fikrini değiştiriyor: artık 1-1, mutabakat düşüyor.
    await oyVer(a, urunB);
    expect(await paylasilan()).toBeNull();
  });

  it('kendi cevabın mutabakatı yeniyor', async () => {
    // Kendi fişinde senin cevabın kazanıyor: paketi eline alan sensin.
    const a = await hesap();
    const b = await hesap();
    await oyVer(a, urunA);
    await oyVer(b, urunA);

    const c = await hesap();
    await oyVer(c, urunB);

    expect((await coz(c))!.canonicalProductId).toBe(urunB);
    expect((await coz(c))!.kendi).toBe(true);
    // Mutabakat hâlâ A'da: 2'ye 1.
    expect((await paylasilan())!.canonical_product_id).toBe(urunA);
  });
});
