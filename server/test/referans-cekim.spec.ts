import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { pool, query } from '../src/db.js';
import { aileler, refreshReference } from '../src/reference/refresh.js';

/**
 * Günlük anlık görüntünün sürdürülebilirliği.
 *
 * Kaynak yalnızca BUGÜNKÜ fiyatı yayımlıyor; toplanmayan günün verisi kalıcı
 * olarak kayıp. Çekim iki buçuk dakika sürüyor ve Render ücretsiz katmanda
 * servis ortada uyuyabiliyor — yani yarıda kesilmek istisna değil, beklenen
 * hâl.
 *
 * Bu testlerin ölçtüğü şey tam olarak bu: kesilen çekim ertesi çağrıda
 * KALDIĞI YERDEN devam ediyor mu, ve karşılığı olmayan aileler kaynağa
 * tekrar tekrar gidiyor mu.
 */

/**
 * Testler tek bir gruba daraltılmış.
 *
 * Sebebi: günlük GERÇEK çekimin ilerlemesini tutuyor ve o gün toplanmayan
 * veri kalıcı olarak kayıp. Bütün günlüğü silen bir test, yerelde süren bir
 * çekimi baştan başlatır ve kaynağa boşuna yük bindirirdi. Bu grubun altı
 * ailesi var; testlerin ihtiyacı olan da bu.
 */
const GRUP = 'Yoğurt';

/** Ağa çıkmayan, hiçbir şey bulamayan kaynak. */
const bosKaynak = (sayac: { istek: string[] }): typeof fetch =>
  (async (_url: string, init?: RequestInit) => {
    const govde = JSON.parse(String(init?.body ?? '{}')) as {
      keywords?: string;
    };
    sayac.istek.push(govde.keywords ?? '');
    return new Response(JSON.stringify({ content: [] }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  }) as unknown as typeof fetch;

/** Yalnızca bu grubun ailelerini temizliyor, bütün günlüğü değil. */
async function gunlugu_temizle(): Promise<void> {
  await query(
    `DELETE FROM reference_fetch_log
      WHERE fetched_on = current_date AND family LIKE '%' || $1`,
    [GRUP],
  );
}

beforeEach(gunlugu_temizle);
afterAll(async () => {
  await gunlugu_temizle();
  await pool.end();
});

describe('Referans çekimi', () => {
  it('kesilen çekim kaldığı yerden sürüyor', async () => {
    const toplam = (await aileler(GRUP)).size;
    expect(toplam).toBe(6);

    const ilk = { istek: [] as string[] };
    const a = await refreshReference({
      grup: GRUP,
      limit: 3,
      fetchImpl: bosKaynak(ilk),
      bekleMs: 0,
    });
    expect(a.denenen).toBe(3);
    expect(a.kalan).toBe(toplam - 3);

    const ikinci = { istek: [] as string[] };
    const b = await refreshReference({
      grup: GRUP,
      limit: 3,
      fetchImpl: bosKaynak(ikinci),
      bekleMs: 0,
    });
    expect(b.denenen).toBe(3);
    // Kalan, ilk turdakinden üç eksik: ikinci tur baştan başlamadı.
    expect(b.kalan).toBe(toplam - 6);

    // Ve hiçbir aile iki kez sorulmadı.
    const kesisim = ilk.istek.filter((k) => ikinci.istek.includes(k));
    expect(kesisim).toEqual([]);
  });

  it('karşılığı olmayan aile aynı gün tekrar sorulmuyor', async () => {
    // Sahte kaynak hiçbir şey bulmuyor, yani bu ailelerin sonucu
    // 'sonuc-yok'. Yine de günlüğe yazılmalı: yazılmasaydı her açılışta
    // yeniden denenir, kamuya açık bir hizmete boşuna yük binerdi.
    const ilk = { istek: [] as string[] };
    await refreshReference({
      grup: GRUP,
      limit: 2,
      fetchImpl: bosKaynak(ilk),
      bekleMs: 0,
    });

    const kayit = await query<{ outcome: string }>(
      `SELECT outcome FROM reference_fetch_log
        WHERE fetched_on = current_date AND family LIKE '%' || $1`,
      [GRUP],
    );
    expect(kayit).toHaveLength(2);
    expect(kayit.every((r) => r.outcome === 'sonuc-yok')).toBe(true);

    const ikinci = { istek: [] as string[] };
    await refreshReference({
      grup: GRUP,
      limit: 2,
      fetchImpl: bosKaynak(ikinci),
      bekleMs: 0,
    });
    const kesisim = ilk.istek.filter((k) => ikinci.istek.includes(k));
    expect(kesisim).toEqual([]);
  });

  it('zorla verilince günlüğe bakmıyor', async () => {
    const ilk = { istek: [] as string[] };
    await refreshReference({
      grup: GRUP,
      limit: 2,
      fetchImpl: bosKaynak(ilk),
      bekleMs: 0,
    });

    const ikinci = { istek: [] as string[] };
    await refreshReference({
      grup: GRUP,
      limit: 2,
      force: true,
      fetchImpl: bosKaynak(ikinci),
      bekleMs: 0,
    });

    expect(ikinci.istek).toEqual(ilk.istek);
  });

  it('kaynak hata verince aile hata olarak kapanıyor, çekim durmuyor', async () => {
    // Tek bir ailenin patlaması bütün günü düşürmemeli.
    const patlayan = (async () => {
      throw new Error('ağ yok');
    }) as unknown as typeof fetch;

    const r = await refreshReference({
      grup: GRUP,
      limit: 2,
      fetchImpl: patlayan,
      bekleMs: 0,
    });

    expect(r.denenen).toBe(2);
    expect(r.dagilim.hata).toBe(2);

    const kayit = await query<{ outcome: string }>(
      `SELECT outcome FROM reference_fetch_log
        WHERE fetched_on = current_date AND family LIKE '%' || $1`,
      [GRUP],
    );
    expect(kayit.every((r) => r.outcome === 'hata')).toBe(true);
  });
});
