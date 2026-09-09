/**
 * Zincirlerin yayımladığı fiyatları çeker.  npm run reference
 *
 * Amaç fiyat göstermek DEĞİL, "hangi boy?" sorusunu cevaplamak: fiş gramaj
 * basmıyor ama fiyat basıyor, zincir de her boyun fiyatını yayımlıyor.
 *
 * Katalog marka+grup ailelerine bölünüp her aile için tek arama yapılıyor —
 * "Sütaş Yoğurt" araması o markanın bütün boylarını birden getiriyor, ürün
 * başına ayrı istek atmaya gerek yok.
 *
 * Kullanım:
 *   npm run reference                    bütün katalog
 *   npm run reference -- --limit 5       ilk beş aile (deneme)
 *   npm run reference -- --grup Yoğurt   tek grup
 *   npm run reference -- --kuru          istek atmadan ne olacağını göster
 */
import { pool, query } from '../src/db.js';
import { searchReference } from '../src/reference/marketfiyati.js';
import {
  boyTutuyorMu,
  kaynakBoyu,
  markaTutuyorMu,
} from '../src/reference/eslestir.js';

const KAYNAK = 'marketfiyati.org.tr';

/** Çağrılar arası bekleme. Kamuya açık, sözleşmesiz bir uca karşı nezaket. */
const BEKLE_MS = 900;

type Kalem = {
  id: string;
  group_name: string;
  brand_name: string | null;
  size_value: string;
  unit: string;
};

const uyu = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function zincirler(): Promise<Map<string, string>> {
  const rows = await query<{ id: string; chain_code: string }>(
    `SELECT id, chain_code FROM merchants`,
  );
  return new Map(rows.map((r) => [r.chain_code, r.id]));
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const kuru = argv.includes('--kuru');
  const limitIdx = argv.indexOf('--limit');
  const limit = limitIdx >= 0 ? Number(argv[limitIdx + 1]) : Infinity;
  const grupIdx = argv.indexOf('--grup');
  const grupFiltre = grupIdx >= 0 ? argv[grupIdx + 1] : null;

  const chainIds = await zincirler();

  // Markasız kalemler dışarıda: kaynakta karşılıkları markalı ürünler ve
  // hangisinin bizim "kilogram domates"imiz olduğu söylenemez. Onlarda
  // sorulacak bir boy da yok.
  const kalemler = await query<Kalem>(
    `SELECT v.id, v.group_name, v.brand_name, v.size_value::text, v.unit::text
       FROM v_canonical_products v
      WHERE v.brand_name IS NOT NULL
        AND ($1::text IS NULL OR v.group_name = $1)
      ORDER BY v.brand_name, v.group_name, v.size_value`,
    [grupFiltre],
  );

  // Aile = marka + grup. Tek arama bütün boylarını getiriyor.
  const aileler = new Map<string, Kalem[]>();
  for (const k of kalemler) {
    const anahtar = `${k.brand_name} ${k.group_name}`;
    const liste = aileler.get(anahtar) ?? [];
    liste.push(k);
    aileler.set(anahtar, liste);
  }

  console.log(`${kalemler.length} kalem, ${aileler.size} aile`);
  if (kuru) {
    for (const [ad, liste] of [...aileler].slice(0, 20)) {
      console.log(`  ${ad} — ${liste.length} boy`);
    }
    await pool.end();
    return;
  }

  let arama = 0;
  let yazilan = 0;
  let eslesenAile = 0;
  const bulunamayan: string[] = [];

  for (const [ad, liste] of aileler) {
    if (arama >= limit) break;
    arama++;

    let items;
    try {
      // Grup adı "Ekmek, tam buğday" gibi virgüllü; arama için düzleştiriyoruz.
      const anahtarKelime = ad.replace(/,/g, ' ').replace(/\s+/g, ' ').trim();
      items = await searchReference(anahtarKelime, 25);
    } catch (err) {
      console.error(`  ! ${ad}: ${(err as Error).message}`);
      await uyu(BEKLE_MS);
      continue;
    }

    let aileYazdi = false;
    // Neden eşleşmediğini saymak, tahmin etmekten iyi: "sonuç yok" ile
    // "sonuç var ama boy tutmuyor" bambaşka iki problem ve bambaşka iki
    // düzeltme istiyor.
    let markaTutan = 0;
    let boyOkunan = 0;

    for (const kalem of liste) {
      const bizimBoy = Number(kalem.size_value);
      for (const item of items) {
        if (!markaTutuyorMu(kalem.brand_name, item.brand)) continue;
        markaTutan++;
        const kaynakBoy = kaynakBoyu(item.sizeText, item.title, kalem.unit);
        if (kaynakBoy !== null) boyOkunan++;
        if (kaynakBoy === null || !boyTutuyorMu(bizimBoy, kaynakBoy)) continue;

        for (const [chain, fiyat] of item.prices) {
          const merchantId = chainIds.get(chain);
          if (!merchantId) continue;
          await query(
            `INSERT INTO reference_prices
               (canonical_product_id, merchant_id, observed_on, price,
                source, source_ref, source_title)
             VALUES ($1, $2, COALESCE($3::date, current_date), $4, $5, $6, $7)
             ON CONFLICT (canonical_product_id, merchant_id, observed_on, source_ref)
             DO UPDATE SET price = EXCLUDED.price,
                           source_title = EXCLUDED.source_title,
                           fetched_at = now()`,
            [
              kalem.id,
              merchantId,
              item.observedOn,
              fiyat,
              KAYNAK,
              item.ref,
              item.title,
            ],
          );
          yazilan++;
          aileYazdi = true;
        }
      }
    }

    if (aileYazdi) eslesenAile++;
    else {
      const neden =
        items.length === 0
          ? 'kaynakta sonuç yok'
          : markaTutan === 0
            ? `marka tutmadı (${items.length} sonuç)`
            : boyOkunan === 0
              ? `boy okunamadı (${markaTutan} markalı sonuç)`
              : `boy tutmadı (${boyOkunan} boyu okunan sonuç)`;
      bulunamayan.push(`${ad} — ${neden}`);
    }

    await uyu(BEKLE_MS);
  }

  console.log(`\narama ${arama} — eşleşen aile ${eslesenAile}, yazılan fiyat ${yazilan}`);
  if (bulunamayan.length > 0) {
    console.log(`karşılığı bulunamayan ${bulunamayan.length} aile:`);
    for (const ad of bulunamayan) console.log(`  ${ad}`);
  }
  await pool.end();
}

void main();
