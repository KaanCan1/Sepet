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
    // Ölçülen: 57'de 48 (%84,2). Taban biraz altında — katalog büyüdükçe
    // bir iki vaka yer değiştirebilir ve testin kırılganlık nöbeti
    // geçirmesi istenmiyor.
    //
    // Oran 52'de 45'ten (%86,5) düşük görünüyor: kümeye eklenen beş
    // yapışık vakanın ikisi hâlâ soruluyor. Küme büyüdü ve zorlaştı,
    // eşleştirme gerilemedi — eski 52 vakanın hepsi aynı sonucu veriyor.
    //
    // Taban 46: yapışık okuma olmadan bu küme tam 45 veriyor, yani bu
    // sayı okumanın kendisini de tutuyor.
    expect(dogru).toBeGreaterThanOrEqual(46);
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

  // Yazıcı adı boşluksuz ve kesik basınca satır okunamaz hâle geliyordu.
  // "LOGİKAĞITHAV12Lİ" için katalogda Kağıt havlu grubu 16 ürünle
  // duruyordu ama aday listesi BOŞ dönüyordu: eşleştirme belirteç
  // bazlıydı ve belirtecin içine bakmıyordu. Aynı satır boşluklu
  // yazıldığında ("KAGIT HAVLU 12LI") 0,69 ile eşleşiyor.
  it('yapışık yazılmış satır doğru grubu buluyor', async () => {
    const o = await matchCatalog('LOGIKAGITHAV12LI', 6);
    expect(o.candidates.length).toBeGreaterThan(0);
    expect(o.candidates[0]!.groupName).toBe('Kağıt havlu');
    // Marka ("Logi") katalogda yok: listedeki bir markaya bağlamak
    // uydurmak olur. Doğru davranış sormak.
    expect(o.auto).toBeNull();
  });

  // Yapışık yazım yanlış eşleşmeyi KOLAYLAŞTIRMAMALI. Belirteç markayı
  // içerdiği için tamamen karşılanmış sayılırsa fişte yazan ürün adı
  // ortadan kayboluyor ve puan, boşluklu hâlinin ÜSTÜNE çıkıyor.
  it('yapışık yazım puanı boşluklu hâlinin üstüne çıkarmıyor', async () => {
    const yapisik = await matchCatalog('BALPARMAKPEKMEZ380G', 6);
    const bosluklu = await matchCatalog('BALPARMAK PEKMEZ 380G', 6);
    expect(yapisik.auto).toBeNull();
    expect(yapisik.best!.score).toBeLessThan(bosluklu.best!.score + 0.05);
  });

  it('boy fişte yazmıyorsa soruluyor', async () => {
    // Paketli üründe boy tahmin edilemez: 1 kg ile 3 kg yoğurdun kilo
    // fiyatı üç kat farklı ve fark doğrudan endekse giriyor.
    const o = await matchCatalog('TAM BUGDAY EKMEK', 6);
    expect(o.sizeAmbiguous).toBe(true);
    expect(o.auto).toBeNull();
  });
});
