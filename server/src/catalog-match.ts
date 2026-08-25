import type { PoolClient } from 'pg';
import { pool } from './db.js';
import { isBulk, sizeStated } from './size-hint.js';

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
   * Kararın verildiği aday — boy süzgecinden GEÇMİŞ havuzun ilki.
   *
   * `candidates[0]` ile aynı olmak zorunda değil: fişte boy yazıyorsa havuz
   * ona göre daraltılıyor ve ham puan sıralamasının başındaki kalem elenmiş
   * olabiliyor. "ERIKLI SU 5L" için ham sıralamanın ilki 500 mL'lik kalem
   * ama karar 5 litrelikle veriliyor. Ölçüm bu ayrımı göremeyince yanlış
   * yerde hata arıyordu.
   */
  best: Candidate | null;
  /**
   * Marka ve grup kesin ama boy belirsiz. Kullanıcıya sorulacak tek şey bu —
   * "1 kg mı 3 kg mı" — ve sorulmak zorunda, çünkü fişte yazmıyor.
   */
  sizeAmbiguous: boolean;
};

/**
 * Otomatik bağlama eşiği. Altındaki her şey kullanıcıya soruluyor.
 *
 * Eskiden 0,85'ti ve iki gerçek fiş üzerinde göz kararı ayarlanmıştı:
 * "doğru aday 0,90'ın üstünde toplanıyor". Genellemedi. Ölçünce doğru
 * cevapların büyük kısmının 0,66–0,70 bandında kaldığı ve eşiğin altına
 * düştüğü için sorulduğu görüldü — eşleştirici doğru cevabı biliyor ama
 * vermeyi reddediyordu.
 *
 * 0,65 taramayla seçildi (scripts/match-eval.ts): 40 etiketli vakada
 * 35 doğru otomatik, 0 yanlış; 18 düşmanca olumsuz vakada 0 yanlış
 * bağlama. 0,62–0,65 aralığı aynı sonucu veriyor, eşik platonun TEPESİNE
 * kondu — en yüksek puanlı olumsuz vaka 0,604 ve aradaki 0,046 kümenin
 * dışındaki verinin emniyet payı.
 *
 * Eşiği daha da düşürmek kümede daha iyi görünür ama olumsuz vakalar
 * bağlanmaya başlıyor; ve yanlış bağlamak sormaktan çok daha pahalı:
 * endeks birim fiyattan hesaplandığı için sessizce yanlış enflasyon
 * üretiyor.
 */
const AUTO_THRESHOLD = 0.65;

/**
 * İkinci adayla arasında bu kadar fark yoksa "kesin" sayılmıyor.
 *
 * Ölçümde bu eşikte bedeli yok (0 ile 0,05 aynı sonucu veriyor) — boy
 * süzgeci yakın adayları zaten ayıklıyor. Bedelsiz olduğu için duruyor:
 * kümenin dışındaki berabere kalan adaylara karşı.
 */
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

  return { candidates, ...decide(raw, candidates) };
}

/** [decide] için ayarlanabilir eşikler — kalibrasyon dışında kullanılmıyor. */
export type DecideOpts = { threshold?: number; margin?: number };

/**
 * Adaylardan karara: hangisi, sorulmalı mı.
 *
 * Veritabanından ayrı duruyor çünkü kalibrasyonun ölçtüğü şey tam olarak
 * bu: eşikleri tarayan betik (scripts/match-eval.ts) adayları bir kez
 * çekip bu fonksiyonu farklı ayarlarla çağırıyor. Karar mantığı iki yere
 * yazılsaydı ölçülen şey ile üretimde çalışan şey sessizce ayrışırdı.
 */
export function decide(
  raw: string,
  candidates: Candidate[],
  opts: DecideOpts = {},
): Omit<MatchOutcome, 'candidates'> {
  const threshold = opts.threshold ?? AUTO_THRESHOLD;
  const margin = opts.margin ?? AUTO_MARGIN;

  if (!candidates.length) {
    return { auto: null, best: null, sizeAmbiguous: false };
  }

  // Fişte boy yazıyorsa adaylar ona göre daraltılıyor: "SUT TAM YAGLI 1L"
  // için 500 mL'lik kalemleri aday tutmanın anlamı yok.
  const stated = candidates.filter((c) =>
    sizeStated(raw, c.unit, c.sizeValue, c.sizeLabel),
  );
  const havuz = stated.length ? stated : candidates;

  const [top, second] = havuz;
  if (!top) return { auto: null, best: null, sizeAmbiguous: false };

  // Boy sorusu iki koşula bağlı ve ikisi de kataloğun ne taşıdığından
  // BAĞIMSIZ. Eskiden "aynı marka ve grubun birden çok boyu var mı" diye
  // bakılıyordu; o kural katalogda tek boy bulunan kalemi sessizce
  // otomatik bağlıyordu. Pınar beyaz peynirin katalogda yalnızca 600 g'ı
  // olması, kullanıcının 600 g aldığı anlamına gelmiyor.
  //
  //   Paketli mi?  Kasada tartılan kalemde (domates, açık kıyma) boy yok.
  //   Fişte var mı? Yazıyorsa sormak kullanıcıyı bildiği şeyle meşgul eder.
  const sizeAmbiguous =
    !isBulk(top.sizeLabel) &&
    !sizeStated(raw, top.unit, top.sizeValue, top.sizeLabel);

  const decisive =
    top.score >= threshold &&
    !sizeAmbiguous &&
    (!second || second.score <= top.score - margin);

  return { auto: decisive ? top : null, best: top, sizeAmbiguous };
}
