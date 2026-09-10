import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pool, query } from '../src/db.js';
import { matchPool } from '../src/reference/havuz-eslestir.js';

/**
 * Havuzu okuyan eşleştirici.
 *
 * Testlerin asıl işi doğru cevabı doğrulamak DEĞİL, yanlış cevabı
 * engellemek. Yanlış bağlanan satır endeksi sessizce bozuyor: boy endeksin
 * böleni, yanlış boy o ürünü "ucuzlamış" gösteriyor. Kullanıcıya sormak
 * yavaştır; yanlış bağlamak bozuktur.
 *
 * Havuz burada elle kuruluyor. Gerçek havuz kaynaktan geliyor ve içeriği
 * gün gün değişiyor; testin ölçtüğü şey içerik değil KARAR KURALI.
 *
 * Marka ve ürün adları UYDURMA. Gerçek adlarla yazılınca test yereldeki
 * gerçek havuzla yarışıyor ve aynı puanı alan gerçek bir kalem tohumun
 * önüne geçebiliyordu — CI'da temiz veritabanında geçen, yerelde düşen bir
 * test. Uydurma ad, tohumun tek başına kalmasını garanti ediyor.
 */

const KAYNAK = 'test-havuz';

type Tohum = {
  ref: string;
  title: string;
  brand: string | null;
  size: number | null;
  unit: 'kilogram' | 'litre' | 'adet' | null;
};

const TOHUM: Tohum[] = [
  // Aynı marka, aynı ürün, FARKLI boy — fiş boy yazmazsa ayrılamazlar.
  { ref: 'z-1', title: 'Testaş Zurna 1 Kg', brand: 'Testaş', size: 1, unit: 'kilogram' },
  { ref: 'z-15', title: 'Testaş Zurna 1.5 Kg', brand: 'Testaş', size: 1.5, unit: 'kilogram' },
  // Aynı boy, farklı çeşit — hangisi seçilirse seçilsin cevap aynı.
  { ref: 'z-1b', title: 'Testaş Kaymaklı Zurna 1 Kg', brand: 'Testaş', size: 1, unit: 'kilogram' },
  // Başka marka, aynı kelimeler.
  { ref: 'z-ek', title: 'Ekeraş Kaymaklı Zurna 1 Kg', brand: 'Ekeraş', size: 1, unit: 'kilogram' },
  // Adet birimi.
  { ref: 'b-6', title: 'Vivaş Borazan 6 Adet', brand: 'Vivaş', size: 6, unit: 'adet' },
  { ref: 'b-2', title: 'Vivaş Borazan 2 Adet', brand: 'Vivaş', size: 2, unit: 'adet' },
];

beforeAll(async () => {
  await query(`DELETE FROM pool_products WHERE source = $1`, [KAYNAK]);
  for (const t of TOHUM) {
    await query(
      `INSERT INTO pool_products
         (source, source_ref, title, brand_text, size_value, unit)
       VALUES ($1, $2, $3, $4, $5, $6::product_unit)`,
      [KAYNAK, t.ref, t.title, t.brand, t.size, t.unit],
    );
  }
});

afterAll(async () => {
  await query(`DELETE FROM pool_products WHERE source = $1`, [KAYNAK]);
  await pool.end();
});

/** Yalnızca test tohumundan gelen adaylar. */
async function eslestir(raw: string) {
  const o = await matchPool(raw, 8);
  const bizim = o.candidates.filter((c) =>
    TOHUM.some((t) => t.title === c.title),
  );
  return { ...o, candidates: bizim };
}

describe('Havuz eşleştirmesi', () => {
  it('marka kanıtı yoksa bağlamıyor', async () => {
    // Gerçek vakanın birebir kopyası: yazarkasa markayı TACIROGLU değil
    // TACIROGLI basmıştı ve satır, markası hiç tutmadığı hâlde "Eker Tam
    // Yağlı Yoğurt" ile 0,667 alıyordu.
    //
    // Burada TESTAZ, TESTAŞ'ın ön eki DEĞİL (son harf farklı) — yani marka
    // kanıtı sıfır. Metin puanı ise 2/3, eşiğin üstünde. Marka koşulu
    // olmasaydı satır güvenle yanlış markaya bağlanırdı.
    const o = await eslestir('TESTAZ KAYMAKLI ZURNA');
    expect(o.candidates.some((c) => c.score >= 0.6)).toBe(true);
    expect(o.candidates.every((c) => !c.brandHit)).toBe(true);
    expect(o.auto).toBeNull();
  });

  it('fiş boy yazıyorsa o boya bağlıyor', async () => {
    const o = await matchPool('TESTAS ZURNA 1.5KG', 8);
    expect(o.auto).not.toBeNull();
    expect(o.auto!.title).toBe('Testaş Zurna 1.5 Kg');
  });

  it('boy metin puanını sulandırmıyor', async () => {
    // "1.5KG" belirteç olarak hiçbir başlığı tutmuyor ("5KG" ne "KG"nin ön
    // eki ne tersi) ve paydaya girseydi doğru kalem 0,667'ye düşerdi —
    // yanlış kalemle aynı puana. Rakam içeren belirteçler bu yüzden metin
    // eşleşmesinden çıkarılıyor; boyun kendi makinesi var.
    const o = await matchPool('TESTAS ZURNA 1.5KG', 8);
    expect(o.candidates[0]!.score).toBe(1);
  });

  it('fişin yazdığı boy havuzda yoksa bağlamıyor', async () => {
    // Fişin söylediğini görmezden gelip başka bir boya bağlamak,
    // kullanıcının elindeki kâğıdı yalanlamak olurdu.
    const o = await eslestir('TESTAS ZURNA 900G');
    expect(o.auto).toBeNull();
  });

  it('fiş boy yazmıyorsa ve boylar ayrışıyorsa soruyor', async () => {
    const o = await eslestir('TESTAS ZURNA');
    expect(o.auto).toBeNull();
    expect(o.sizeAmbiguous).toBe(true);
  });

  it('aynı boyda iki çeşit varsa bağlıyor — cevap aynı', async () => {
    // "Testaş Zurna 1 Kg" ile "Testaş Kaymaklı Zurna 1 Kg" berabere
    // kalabilir; ikisi de 1 kg olduğu için endeks açısından fark yok.
    const o = await matchPool('TESTAS ZURNA 1KG', 8);
    expect(o.auto).not.toBeNull();
    expect(o.auto!.sizeValue).toBe(1);
    expect(o.auto!.unit).toBe('kilogram');
  });

  it('adet biriminde de çalışıyor', async () => {
    const o = await eslestir('VIVAS BORAZAN 6LI');
    expect(o.auto).not.toBeNull();
    expect(o.auto!.title).toBe('Vivaş Borazan 6 Adet');
  });

  it('hiç benzemeyen satırda aday üretmiyor', async () => {
    const o = await eslestir('KASA POSETI');
    expect(o.candidates).toEqual([]);
    expect(o.auto).toBeNull();
  });
});
