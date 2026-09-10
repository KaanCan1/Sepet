/**
 * Zincirlerin yayımladığı fiyatları çeker.  npm run reference
 *
 * Amaç fiyat göstermek DEĞİL, "hangi boy?" sorusunu cevaplamak: fiş gramaj
 * basmıyor ama fiyat basıyor, zincir de her boyun fiyatını yayımlıyor.
 *
 * İşin kendisi `src/reference/refresh.ts` içinde — sunucu da açılışta aynı
 * fonksiyonu çağırıyor. Burası yalnızca elle tetiklemek ve ne olduğunu
 * görmek için.
 *
 * Kullanım:
 *   npm run reference                    bugün kalanları çek
 *   npm run reference -- --limit 5       yalnızca beş aile
 *   npm run reference -- --grup Yoğurt   tek grup
 *   npm run reference -- --zorla         günlüğe bakma, hepsini yeniden dene
 */
import { refreshReferenceCli, type Sonuc } from '../src/reference/refresh.js';

const argv = process.argv.slice(2);
const say = (bayrak: string): number | undefined => {
  const i = argv.indexOf(bayrak);
  return i >= 0 ? Number(argv[i + 1]) : undefined;
};
const metin = (bayrak: string): string | undefined => {
  const i = argv.indexOf(bayrak);
  return i >= 0 ? argv[i + 1] : undefined;
};

const kacan: string[] = [];

const sonuc = await refreshReferenceCli({
  limit: say('--limit'),
  grup: metin('--grup') ?? null,
  force: argv.includes('--zorla'),
  onFamily: (ad, s: Sonuc, n) => {
    if (s === 'yazildi') console.log(`  ✓ ${ad} — ${n} fiyat`);
    else kacan.push(`${ad} — ${s}`);
  },
});

console.log(
  `\ndenenen ${sonuc.denenen} — yazılan fiyat ${sonuc.yazilan}, bugün kalan ${sonuc.kalan}`,
);
// Sebep ayrımı önemli: "kaynakta sonuç yok" kataloğun kaynakta karşılığı
// olmaması, "boy tutmadı" bizim boy okuyucumuzun eksiği. İkisi bambaşka
// iki iş.
for (const [s, n] of Object.entries(sonuc.dagilim)) {
  if (n > 0 && s !== 'yazildi') console.log(`  ${s}: ${n} aile`);
}
if (kacan.length > 0 && argv.includes('--ayrinti')) {
  console.log('\nkaçanlar:');
  for (const k of kacan) console.log(`  ${k}`);
}
