import type { PoolClient } from 'pg';
import { pool } from './db.js';

/** Bulanık eşleştirmeden dönen tek aday. */
export type Candidate = {
  id: string;
  displayName: string;
  shortName: string;
  groupId: string;
  groupName: string;
  brandId: string | null;
  brandName: string | null;
  sizeLabel: string;
  /** Paket içeriği kanonik birim cinsinden: 400 g -> 0,4 (kilogram). */
  sizeValue: number;
  /** Grubun kanonik birimi: litre, kilogram ya da adet. */
  unit: string;
  score: number;
};

export type MatchOutcome = {
  candidates: Candidate[];
  /** Soru sormadan bağlanabilecek ürün. Yoksa null. */
  auto: Candidate | null;
  /**
   * Marka ve grup kesin ama boy belirsiz. Kullanıcıya sorulacak tek şey bu —
   * "1 kg mı 3 kg mı" — ve sorulmak zorunda, çünkü fişte yazmıyor.
   */
  sizeAmbiguous: boolean;
};

/**
 * Otomatik bağlama eşiği. Altındaki her şey kullanıcıya soruluyor.
 *
 * 0,85 iki gerçek fiş üzerinde ayarlandı: doğru aday 0,90'ın üstünde
 * toplanıyor, yanlış adaylar 0,70'in altında kalıyor. Arada geniş bir boşluk
 * var, eşik oraya kondu.
 */
const AUTO_THRESHOLD = 0.85;

/** İkinci adayla arasında bu kadar fark yoksa "kesin" sayılmıyor. */
const AUTO_MARGIN = 0.05;

/** Kullanıcıya aday olarak göstermeye değer alt sınır. */
const SUGGEST_THRESHOLD = 0.35;

export async function matchCatalog(
  raw: string,
  limit = 5,
  client?: PoolClient,
): Promise<MatchOutcome> {
  const runner = client ?? pool;
  const { rows } = await runner.query(
    `SELECT v.id, v.display_name, v.short_name, v.group_id, v.group_name,
            v.brand_id, v.brand_name, v.size_label, v.size_value, v.unit,
            m.score
       FROM catalog_match($1, $2) m
       JOIN v_canonical_products v ON v.id = m.canonical_product_id
      ORDER BY m.score DESC, v.size_value`,
    [raw, limit],
  );

  const candidates: Candidate[] = rows
    .map((r) => ({
      id: r.id as string,
      displayName: r.display_name as string,
      shortName: r.short_name as string,
      groupId: r.group_id as string,
      groupName: r.group_name as string,
      brandId: r.brand_id as string | null,
      brandName: r.brand_name as string | null,
      sizeLabel: r.size_label as string,
      sizeValue: Number(r.size_value),
      unit: r.unit as string,
      score: Number(r.score),
    }))
    .filter((c) => c.score >= SUGGEST_THRESHOLD);

  const [top, second] = candidates;
  if (!top) return { candidates: [], auto: null, sizeAmbiguous: false };

  // Aynı marka + aynı grup, farklı boy: fişte gramaj yazmadığı için
  // ayırt edilemez. Buradan otomatik seçim yapmak endeksi bozar — 3 kg
  // yoğurdu 1 kg sanmak birim fiyatı üçe katlar.
  const sizeAmbiguous =
    !!second &&
    second.groupId === top.groupId &&
    second.brandId === top.brandId &&
    second.score >= top.score - AUTO_MARGIN;

  const decisive =
    top.score >= AUTO_THRESHOLD &&
    !sizeAmbiguous &&
    (!second || second.score <= top.score - AUTO_MARGIN);

  return { candidates, auto: decisive ? top : null, sizeAmbiguous };
}
