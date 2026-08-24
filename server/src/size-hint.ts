/**
 * Fiş metninde paket boyu yazıyor mu?
 *
 * Yazarkasa çoğu kalemde boyu basmıyor ("MIGROS T.YAGLI YOGU.") ama bazen
 * basıyor ("SUT TAM YAGLI 1L", "YUMURTA 30LU", "PROTEIN BAR 50 G"). Bu ikisini
 * ayırmak eşleştirmenin doğruluğunu belirliyor:
 *
 * - Boy yazıyorsa sormak gereksiz; kullanıcıyı bildiği bir şeyle meşgul eder.
 * - Yazmıyorsa sormak zorunlu; endeks birim fiyattan hesaplandığı için
 *   tahmin sessizce yanlış enflasyon üretir.
 */

/** Sadeleştirme — SQL'deki normalize_raw_text ile aynı düzlem. */
function flatten(text: string): string {
  const from = 'ıİğĞüÜşŞöÖçÇ';
  const to = 'IIGGUUSSOOCC';
  return [...text]
    .map((ch) => {
      const i = from.indexOf(ch);
      return i >= 0 ? to[i] : ch;
    })
    .join('')
    .toUpperCase();
}

/** Ağırlık ve hacim: "500ML", "1,5 KG", "200 GR". */
const MEASURE = /(\d+(?:[.,]\d+)?)\s*(KG|GR|G|ML|CL|LT|LITRE|L)\b/g;

/** Adet: "30LU", "6LI", "8 LI". Sadeleştirmede LÜ -> LU oluyor. */
const COUNT = /(\d+)\s*(LU|LI)\b/g;

/**
 * Metinde geçen boyları grubun kanonik birimi cinsinden döndürür.
 * Kilogram grubunda "200 GR" -> 0,2; litre grubunda "500ML" -> 0,5.
 */
export function sizesIn(raw: string, unit: string): number[] {
  const flat = flatten(raw);
  const out: number[] = [];

  if (unit === 'adet') {
    for (const m of flat.matchAll(COUNT)) out.push(Number(m[1]));
    return out;
  }

  for (const m of flat.matchAll(MEASURE)) {
    const value = Number(m[1]!.replace(',', '.'));
    if (!Number.isFinite(value) || value <= 0) continue;
    const suffix = m[2]!;
    if (unit === 'kilogram') {
      if (suffix === 'KG') out.push(value);
      else if (suffix === 'G' || suffix === 'GR') out.push(value / 1000);
    } else if (unit === 'litre') {
      if (suffix === 'L' || suffix === 'LT' || suffix === 'LITRE') {
        out.push(value);
      } else if (suffix === 'ML') out.push(value / 1000);
      else if (suffix === 'CL') out.push(value / 100);
    }
  }
  return out;
}

/**
 * Boy etiketinin kendisi metinde geçiyor mu?
 *
 * Kanonik birim her zaman etiketin birimi değil: protein barın grubu "adet",
 * boyu 1, ama etiketi "50 g" ve fişte de "PROTEIN BAR 50 G" yazıyor. Kanonik
 * karşılaştırma bunu kaçırıyor, etiketin kendisini aramak yakalıyor.
 */
function labelStated(raw: string, sizeLabel: string): boolean {
  const m = /(\d+(?:[.,]\d+)?)\s*([A-Z]+)/.exec(flatten(sizeLabel));
  if (!m) return false;
  const value = m[1]!.replace(',', '.');
  const unit = m[2]!;
  const pattern = new RegExp(
    `${value.replace('.', '[.,]')}\\s*${unit}\\b`,
  );
  return pattern.test(flatten(raw));
}

/** Metindeki boy bu kaleme denk geliyor mu? */
export function sizeStated(
  raw: string,
  unit: string,
  sizeValue: number,
  sizeLabel = '',
): boolean {
  if (sizeLabel && labelStated(raw, sizeLabel)) return true;
  if (!(sizeValue > 0)) return false;
  return sizesIn(raw, unit).some(
    (v) => Math.abs(v - sizeValue) <= sizeValue * 0.01,
  );
}

/**
 * Kasada tartılan kalem mi?
 *
 * Boy etiketi birimin kendisiyse ("kilogram", "litre", "adet") paket yok
 * demektir: domates, açık kıyma, piliç bonfile. Bunlarda sorulacak bir boy
 * da yok — fiş zaten kilo cinsinden miktarı basıyor.
 */
export function isBulk(sizeLabel: string): boolean {
  return ['kilogram', 'litre', 'adet'].includes(sizeLabel.trim().toLowerCase());
}
