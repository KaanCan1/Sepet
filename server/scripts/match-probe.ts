/**
 * Tek tek fiş satırlarını eşleştiriciye sokup ne olduğunu gösterir.
 *
 * `match-eval` toplu bir not veriyor; bu betik TEK bir satırın neden
 * eşleşmediğini söylüyor: hangi adaylar geldi, puanları ne, karar neydi.
 * Takma ad yazarken gereken şey bu — bir satırın niye tutmadığını bilmeden
 * doğru takma adı yazmak tahmin olur.
 *
 * Kullanım:
 *   npx tsx scripts/match-probe.ts "MIGROS T.YAGLI YOGU."   verilen metinler
 *   npx tsx scripts/match-probe.ts --pending                 veritabanındaki
 *                                                            eşleşmemiş satırlar
 *
 * `--pending` kasıtlı: gerçek fişlerden gelip eşleşmeden kalmış satırlar,
 * eşleştiricinin gerçek dünyadaki hata kümesi. Uydurulmuş bir listeden
 * çok daha değerli.
 */
import { pool, query } from '../src/db.js';
import { matchCatalog } from '../src/catalog-match.js';

async function bekleyenSatirlar(): Promise<string[]> {
  const rows = await query<{ raw_text: string }>(
    `SELECT DISTINCT l.raw_text
       FROM receipt_lines l
      WHERE l.canonical_product_id IS NULL
        AND l.status = 'pending'
      ORDER BY l.raw_text`,
  );
  return rows.map((r) => r.raw_text);
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const metinler = argv.includes('--pending')
    ? await bekleyenSatirlar()
    : argv.filter((a) => !a.startsWith('--'));

  if (metinler.length === 0) {
    console.error('Ölçülecek satır yok. Metin ver ya da --pending kullan.');
    process.exitCode = 1;
    return;
  }

  let otomatik = 0;
  let adaysiz = 0;

  for (const raw of metinler) {
    const o = await matchCatalog(raw, 6);
    const karar = o.auto
      ? `OTOMATİK → ${o.auto.displayName}`
      : o.candidates.length === 0
        ? 'ADAY YOK'
        : o.sizeAmbiguous
          ? 'SORULUR (boy belirsiz)'
          : 'SORULUR (puan yetersiz)';

    if (o.auto) otomatik++;
    if (o.candidates.length === 0) adaysiz++;

    console.log(`\n${raw}`);
    console.log(`  ${karar}`);
    for (const c of o.candidates.slice(0, 4)) {
      console.log(`    ${c.score.toFixed(3)}  ${c.displayName}`);
    }
  }

  console.log(
    `\n${metinler.length} satır — otomatik: ${otomatik}, hiç adayı olmayan: ${adaysiz}`,
  );
  await pool.end();
}

void main();
