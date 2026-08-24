/**
 * Fişte tutarı olan ama endekse girmemesi gereken satırlar.
 *
 * Kasa poşeti bir ürün değil, alışverişin masrafı. Kişisel enflasyon
 * sepetine koymak iki türlü yanlış olurdu: poşet fiyatı yoğurt fiyatıyla
 * aynı sepette ağırlıklanır, ve kullanıcıya hiçbir zaman doğru cevabı
 * olmayan bir "bu hangi ürün?" sorusu sorulur.
 *
 * Liste kasıtlı olarak dar tutuldu. Şüpheli bir kalemi sessizce elemek,
 * kullanıcıya sormaktan daha kötü — eleme yalnızca kalemin ürün olmadığı
 * kesinken yapılıyor.
 */

/** Sadeleştirilmiş metinde aranan kalıplar. */
const PATTERNS = [
  /\bPOSET\b/,
  /\bPOSETI\b/,
  /\bTASIMA\s+POSET/,
  /\bKASA\s+POSET/,
  /\bDEPOZITO\b/,
  /\bHURDA\b/,
  /\bSERVIS\s+BEDELI\b/,
  /\bTASIMA\s+BEDELI\b/,
];

/** Türkçe harfleri düşürüp büyük harfe çeker — SQL'deki normalize_raw_text ile aynı. */
function flatten(text: string): string {
  const from = 'ıİğĞüÜşŞöÖçÇ';
  const to = 'IIGGUUSSOOCC';
  const mapped = [...text]
    .map((ch) => {
      const i = from.indexOf(ch);
      return i >= 0 ? to[i] : ch;
    })
    .join('');
  return mapped.toUpperCase().replace(/[^A-Z0-9]+/g, ' ').trim();
}

export function isNonIndexLine(raw: string): boolean {
  const flat = flatten(raw);
  return PATTERNS.some((p) => p.test(flat));
}
