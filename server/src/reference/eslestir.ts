/**
 * Kaynaktaki ürünü bizim kanonik kalemimize bağlar.
 *
 * Tek soruyu cevaplamak için var: kaynaktaki "Viva Kağıt Havlu 6 Adet"
 * bizim hangi kalemimiz? Cevap yanlışsa sonuç sessizce yanlış boy seçtirir,
 * o yüzden eşleşme GEVŞEK değil KATI: marka ve boy tutmuyorsa bağlanmıyor.
 */
import { sizesIn } from '../size-hint.js';

/** Sadeleştirme — SQL'deki normalize_raw_text ile aynı düzlem. */
export function duzle(text: string): string {
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

/**
 * Adet grubunda sayı. Kaynak "6 Adet" yazıyor, fiş "6'LI" yazıyor;
 * [sizesIn] fişin dilini biliyor, kaynağınkini bilmiyor.
 *
 * Fiş ayrıştırıcısına ADET eklemedim: orası kullanıcının verisine dokunuyor
 * ve kendi ölçümünü hak ediyor. Burası yalnızca kaynağı okuyor.
 */
const ADET = /(\d+)\s*(?:ADET|ADETLI|LU|LI)\b/g;

/**
 * Kaynaktaki boyu grubun kanonik birimine çevirir. Bulamazsa null.
 *
 * Hem boy alanına hem başlığa bakıyor: alan çoğu üründe dolu ama bazen boş
 * geliyor ("Viva Kağıt Havlu 6 Adet" için null) ve boy yalnızca başlıkta
 * yazıyor.
 */
export function kaynakBoyu(
  sizeText: string | null,
  title: string,
  unit: string,
): number | null {
  for (const metin of [sizeText, title]) {
    if (!metin) continue;

    if (unit === 'adet') {
      const flat = duzle(metin);
      for (const m of flat.matchAll(ADET)) {
        const v = Number(m[1]);
        if (Number.isFinite(v) && v > 0) return v;
      }
      continue;
    }

    const bulunan = sizesIn(metin, unit);
    if (bulunan.length > 0) return bulunan[0]!;
  }
  return null;
}

/**
 * Marka aynı mı? Kaynak "Taciroğlu" yazıyor, bizde "Tacıroğlu" — sadeleştirme
 * ikisini de TACIROGLU yapıyor.
 *
 * Markasız kalemler (domates, açık kıyma) hiç eşleşmiyor: kaynakta karşılığı
 * markalı ürünler ve hangisinin bizim "kilogram domates"imiz olduğu
 * söylenemez. Zaten onlarda sorulacak bir boy da yok.
 */
export function markaTutuyorMu(
  bizim: string | null,
  kaynak: string | null,
): boolean {
  if (!bizim || !kaynak) return false;
  return duzle(bizim) === duzle(kaynak);
}

/** İki boy aynı mı — ondalık gürültüsüne karşı binde bir pay. */
export function boyTutuyorMu(bizim: number, kaynak: number): boolean {
  return Math.abs(bizim - kaynak) <= Math.max(bizim, kaynak) * 0.001;
}
