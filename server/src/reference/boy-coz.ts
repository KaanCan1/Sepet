/**
 * Fişteki fiyattan boyu çözer.
 *
 * Yazarkasa gramaj basmıyor ama FİYAT basıyor. Zincir de her boyun fiyatını
 * yayımlıyor. İkisi birebir tutuyorsa boy tahmin edilmiş olmuyor,
 * kanıtlanmış oluyor:
 *
 *   "VIVA HAVLU GLI"  fişte 89,95
 *   yayımlanan        "Viva Kağıt Havlu 6 Adet", Migros, 89,95
 *   sonuç             6'lı — çünkü 2'li, 4'lü ve 8'li başka fiyatlarda
 *
 * ÜÇ KATI KOŞUL. Hepsi birden tutmuyorsa cevap null ve kullanıcıya soruluyor:
 *
 * 1. AYNI ZİNCİR. A101'in fiyatı Migros fişindeki satırı çözemez.
 * 2. KURUŞU KURUŞUNA. Yaklaşık eşleşme yok — 89,95 ile 89,90 farklı iki
 *    üründür. Yakınlık aramak, promosyonlu bir başka boya denk gelme
 *    riskini açar.
 * 3. TEK BOY. Eşleşen referanslar iki farklı boya işaret ediyorsa cevap yok.
 *    İki boy aynı fiyata satılıyorsa fiyat o soruyu cevaplamıyor demektir.
 *
 * Boy çözülse bile FİYAT ENDEKSE GİRMİYOR. Endekse giren tek sayı
 * kullanıcının kendi fişindeki tutar; referans yalnızca o tutarın hangi
 * pakete ait olduğunu söylüyor.
 */
import type { PoolClient } from 'pg';
import { query } from '../db.js';

/** Referansın kaç gün eskisine bakılacağı. */
const PENCERE_GUN = 14;

export type BoyKaniti = {
  canonicalProductId: string;
  price: number;
  sourceTitle: string;
  observedOn: string;
};

export type BoyCozumu =
  | { cozuldu: true; kanit: BoyKaniti }
  | { cozuldu: false; sebep: 'referans-yok' | 'fiyat-tutmadi' | 'birden-cok-boy' };

type Satir = {
  canonical_product_id: string;
  size_value: string;
  price: string;
  source_title: string;
  observed_on: string;
};

export async function boyCoz(
  opts: {
    /** Boy dışında her şeyi tutan aday kalemlerin kimlikleri. */
    adayIds: string[];
    /** Fişteki birim fiyat: satır tutarı / miktar. */
    birimFiyat: number;
    merchantId: string;
    /** Fişin tarihi (YYYY-AA-GG). */
    tarih: string;
    pencereGun?: number;
  },
  /**
   * Fiş kaydı tek işlemde yazılıyor. Çözüm de o işlemin İÇİNDEN okumalı,
   * yoksa aynı istekte yazılan bir şeyi göremez ve daha kötüsü, işlem geri
   * alınırsa çözüm dışarıda kalır.
   */
  client?: PoolClient,
): Promise<BoyCozumu> {
  const { adayIds, birimFiyat, merchantId, tarih } = opts;
  if (adayIds.length < 2 || !(birimFiyat > 0)) {
    return { cozuldu: false, sebep: 'referans-yok' };
  }

  const pencere = opts.pencereGun ?? PENCERE_GUN;
  const calistir = client
    ? async (sql: string, params: unknown[]) =>
        (await client.query<Satir>(sql, params)).rows
    : (sql: string, params: unknown[]) => query<Satir>(sql, params);

  const satirlar = await calistir(
    `SELECT r.canonical_product_id, v.size_value::text, r.price::text,
            r.source_title, r.observed_on::text
       FROM reference_prices r
       JOIN v_canonical_products v ON v.id = r.canonical_product_id
      WHERE r.canonical_product_id = ANY($1::uuid[])
        AND r.merchant_id = $2
        AND r.observed_on BETWEEN $3::date - $4::int AND $3::date + $4::int
      ORDER BY abs(r.observed_on - $3::date)`,
    [adayIds, merchantId, tarih, pencere],
  );

  if (satirlar.length === 0) {
    return { cozuldu: false, sebep: 'referans-yok' };
  }

  // Kuruşu kuruşuna. numeric metin olarak geliyor; kuruşa çevirip tam sayı
  // karşılaştırıyoruz — kayan nokta bu işte güvenilir değil.
  const kurus = (v: number | string) => Math.round(Number(v) * 100);
  const hedef = kurus(birimFiyat);
  const tutanlar = satirlar.filter((s) => kurus(s.price) === hedef);

  if (tutanlar.length === 0) {
    return { cozuldu: false, sebep: 'fiyat-tutmadi' };
  }

  const boylar = new Set(tutanlar.map((s) => s.size_value));
  if (boylar.size > 1) {
    return { cozuldu: false, sebep: 'birden-cok-boy' };
  }

  const kazanan = tutanlar[0]!;
  return {
    cozuldu: true,
    kanit: {
      canonicalProductId: kazanan.canonical_product_id,
      price: Number(kazanan.price),
      sourceTitle: kazanan.source_title,
      observedOn: kazanan.observed_on,
    },
  };
}
