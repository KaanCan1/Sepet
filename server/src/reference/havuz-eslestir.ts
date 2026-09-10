/**
 * Fiş satırını havuzdaki ürüne bağlar.
 *
 * `catalog_match` sepete bakıyor: doksan altı grup, ağırlıklarıyla. Havuz ise
 * zincirlerin sattığı her şey — sepette karşılığı olmayan bir satırın
 * TANINABİLECEĞİ tek yer.
 *
 * Puanı SQL veriyor (`pool_match`), kararı burası. Ayrım kasıtlı: puan
 * "metin ne kadar benziyor" sorusunun cevabı, karar ise "bu kadar benzerlik
 * soru sormadan bağlamaya yeter mi" sorusunun. İkincisi ürün kararı ve
 * ölçülerek değişiyor.
 *
 * ÜÇ KOŞUL, üçü de ölçülerek kondu:
 *
 * 1. MARKA KANITI ŞART. "TACIROGLI TAM YAGLI" satırı — yazarkasa markayı
 *    TACIROGLU değil TACIROGLI basmış — "Eker Tam Yağlı Yoğurt" ve "Torku
 *    Tam Yağlı Yoğurt" ile 0,667 alıyor. Metin puanı yüksek, markanın
 *    kanıtı sıfır. Marka koşulu olmasaydı bu satır güvenle YANLIŞ markaya
 *    bağlanırdı.
 *
 * 2. FİŞ BOY YAZIYORSA BOY TUTMALI. "SUTAS AYRAN 1L" fişte boyu basıyor;
 *    havuzda 200 mL'den 2,5 L'ye altı Sütaş ayranı var ve metin puanı
 *    hepsinde aynı. Fişin yazdığı boy elenmeye yetiyor.
 *
 * 3. HAYATTA KALANLAR TEK BOYU GÖSTERMELİ. "Sütaş Yoğurt 1 Kg" ile "Sütaş
 *    Kaymaklı Tava Yoğurt 1 Kg" aynı puanı alıyor ve ikisi de 1 kg — hangisi
 *    seçilirse seçilsin cevap aynı. Ama 1 kg ile 1,5 kg berabere kalırsa
 *    cevap yok: boy endeksin böleni ve yanlışı sessizce yanlış enflasyon
 *    üretiyor.
 */
import type { PoolClient } from 'pg';
import { query } from '../db.js';
import { sizeStated, sizesIn } from '../size-hint.js';

/**
 * Metin puanı eşiği.
 *
 * 0,667 = üç belirteçten ikisi. Bunun altında eşleşmeyen belirteç
 * eşleşenden çok oluyor. Gerçek fiş satırlarında doğru cevaplar 0,667 ve
 * 1,0'da toplanıyor, yanlışlar 0,333'te — ama bu dokuz satırlık bir gözlem.
 * Sepet tarafındaki eşik göz kararı konup genellememişti; buranın da
 * etiketli bir kümeyle kalibre edilmesi gerekiyor (bkz. match-eval).
 */
const ESIK = 0.6;

export type PoolCandidate = {
  id: string;
  score: number;
  brandHit: boolean;
  title: string;
  sizeValue: number | null;
  unit: string | null;
  /** Sepette karşılığı varsa. Yoksa ürün tanınıyor ama endekse girmiyor. */
  canonicalProductId: string | null;
};

export type PoolOutcome = {
  candidates: PoolCandidate[];
  /** Soru sormadan bağlanabilecek kalem. Yoksa null. */
  auto: PoolCandidate | null;
  /** Marka ve ürün kesin, belirsiz olan tek şey boy. */
  sizeAmbiguous: boolean;
};

const BIRIMLER = ['kilogram', 'litre', 'adet'] as const;

/** Fiş satırı paket boyunu yazıyor mu — hangi birimde olduğu önemli değil. */
export function boyYaziyorMu(raw: string): boolean {
  return BIRIMLER.some((u) => sizesIn(raw, u).length > 0);
}

/** Aynı kalem mi — endeks açısından. Boy aynıysa çeşit farkı fark etmiyor. */
function ayniBoy(a: PoolCandidate, b: PoolCandidate): boolean {
  return a.unit === b.unit && a.sizeValue === b.sizeValue;
}

export function decidePool(
  raw: string,
  candidates: PoolCandidate[],
): Omit<PoolOutcome, 'candidates'> {
  // 1. Marka kanıtı olmayan aday bağlanmıyor.
  let havuz = candidates.filter((c) => c.brandHit);
  if (havuz.length === 0) return { auto: null, sizeAmbiguous: false };

  // 2. Fiş boy yazıyorsa, yazdığı boyu tutmayanlar eleniyor. Hiçbiri
  //    tutmuyorsa cevap yok: fişin söylediğini görmezden gelip başka bir
  //    boya bağlamak, kullanıcının elindeki kâğıdı yalanlamak olur.
  if (boyYaziyorMu(raw)) {
    havuz = havuz.filter(
      (c) =>
        c.unit !== null &&
        c.sizeValue !== null &&
        sizeStated(raw, c.unit, c.sizeValue),
    );
    if (havuz.length === 0) return { auto: null, sizeAmbiguous: false };
  }

  const enIyi = Math.max(...havuz.map((c) => c.score));
  if (enIyi < ESIK) return { auto: null, sizeAmbiguous: false };

  const basta = havuz.filter((c) => c.score === enIyi);

  // 3. Başta duranların hepsi aynı boyu göstermiyorsa cevap yok.
  const tekBoy = basta.every((c) => ayniBoy(c, basta[0]!));
  if (!tekBoy) return { auto: null, sizeAmbiguous: true };

  return { auto: basta[0]!, sizeAmbiguous: false };
}

type Satir = {
  pool_product_id: string;
  score: string;
  brand_hit: boolean;
  title: string;
  size_value: string | null;
  unit: string | null;
  canonical_product_id: string | null;
};

export async function matchPool(
  raw: string,
  limit = 6,
  client?: PoolClient,
): Promise<PoolOutcome> {
  const calistir = client
    ? async (sql: string, params: unknown[]) =>
        (await client.query<Satir>(sql, params)).rows
    : (sql: string, params: unknown[]) => query<Satir>(sql, params);

  const rows = await calistir(`SELECT * FROM pool_match($1, $2)`, [raw, limit]);

  const candidates: PoolCandidate[] = rows.map((r) => ({
    id: r.pool_product_id,
    score: Number(r.score),
    brandHit: r.brand_hit,
    title: r.title,
    sizeValue: r.size_value === null ? null : Number(r.size_value),
    unit: r.unit,
    canonicalProductId: r.canonical_product_id,
  }));

  return { candidates, ...decidePool(raw, candidates) };
}
