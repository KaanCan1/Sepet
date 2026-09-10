import { afterAll, describe, expect, it } from 'vitest';
import { pool } from '../src/db.js';
import { matchCatalog } from '../src/catalog-match.js';

/**
 * Niteliğin tek başına grup kanıtı olmaması.
 *
 * Grup adları "baş, nitelik" düzeninde: "Süt, tam yağlı", "Kıyma, dana",
 * "Ekmek, tam buğday". Baş ürünün KENDİSİ, nitelik onu daraltan sıfat — ve
 * aynı sıfat başka ürünlerin adında da geçiyor.
 *
 * Gerçek vaka: "TACIROGLI TAM YAGLI" bir PEYNİR. "Süt, tam yağlı" grubundan
 * 2/3 alıp 0,599'la başa geçiyordu ve dahası "yalnızca boy belirsiz"
 * sayılıyordu — kullanıcıya SÜTÜN hangi boyu olduğu soruluyordu. Sorunun
 * öncülü yanlış, dolayısıyla cevabı da yok.
 */

afterAll(async () => {
  await pool.end();
});

describe('Nitelik tek başına grup kanıtı değil', () => {
  it('baş fişte geçmiyorsa grup puanı vermiyor', async () => {
    // Fişte SÜT kelimesi yok; puanı veren yalnızca "tam yağlı" sıfatıydı.
    const o = await matchCatalog('TACIROGLI TAM YAGLI', 5);
    const sut = o.candidates.find((c) => c.groupName === 'Süt, tam yağlı');
    // Aday olarak görünebilir (marka benzerliği ve trigram hâlâ çalışıyor)
    // ama grubun katkısı kalktığı için eşiğin çok altında.
    if (sut) expect(sut.score).toBeLessThan(0.5);
    expect(o.auto).toBeNull();
  });

  it('öncülü yanlış olan boy sorusunu sormuyor', async () => {
    // Asıl kullanıcı etkisi bu: "hangi boy?" yerine "hangi ürün?" akışı.
    const o = await matchCatalog('TACIROGLI TAM YAGLI', 5);
    expect(o.sizeAmbiguous).toBe(false);
  });

  it('baş tutunca grup eskisi gibi puanlıyor', async () => {
    // "SÜT" fişte geçiyor: kapı açık, davranış değişmiyor.
    const o = await matchCatalog('SUT TAM YAGLI 1L', 5);
    expect(o.auto).not.toBeNull();
    expect(o.auto!.groupName).toBe('Süt, tam yağlı');
  });

  it('meşru boy sorusu duruyor', async () => {
    // Ürün kesin, fişte gramaj yok: sorulacak gerçek bir soru var.
    const o = await matchCatalog('TAM BUGDAY EKMEK', 5);
    expect(o.sizeAmbiguous).toBe(true);
    expect(o.best!.groupName).toBe('Ekmek, tam buğday');
  });

  it('virgülsüz grup etkilenmiyor', async () => {
    // Doksan altı grubun yetmiş birinde baş adın kendisi.
    const o = await matchCatalog('SUTAS YOGURT 1.5KG', 5);
    expect(o.auto).not.toBeNull();
    expect(o.auto!.groupName).toBe('Yoğurt');
  });
});
