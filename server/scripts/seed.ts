/**
 * Demo hesabı: 12 aylık fiş geçmişi.
 *
 * İki işe yarıyor. Biri geliştirme — Flutter'ı gerçek veriye bağlarken
 * gösterecek bir şey olsun. Diğeri App Store incelemesi: boş kabuk gönderilen
 * uygulamalar "minimum functionality" gerekçesiyle geri dönüyor, inceleme
 * notuna dolu bir demo hesabın bilgileri yazılmalı.
 */
import { one, pool, query } from '../src/db.js';

// Varsayılan demo hesabı; farklı bir adres için:  npm run seed -- ad@ornek.com
const DEMO_EMAIL = process.argv[2] ?? 'demo@sepet.app';

/** Aylık enflasyon oranı — kalem bazında farklı, gerçekçi bir dağılım. */
const CATALOG: Array<{
  name: string;
  size: string;
  startPrice: number;
  monthlyDrift: number;
  /** Kaç ayda bir alınıyor. 1 = her ay. */
  every: number;
  /** Fişte görünen ham metin. */
  raw: string;
  qty?: number;
  /** Mevsimsel kalem: yaz aylarında ucuzluyor. */
  seasonal?: boolean;
}> = [
  { name: 'Süt, tam yağlı', size: '1 litre', startPrice: 27.5, monthlyDrift: 0.031, every: 1, raw: 'SUT TAM YAGLI 1L', qty: 3 },
  { name: 'Yumurta', size: "30'lu", startPrice: 121, monthlyDrift: 0.037, every: 1, raw: 'YUMURTA 30LU' },
  { name: 'Beyaz peynir', size: '600 g', startPrice: 142.5, monthlyDrift: 0.036, every: 1, raw: 'BEYAZ PEYNIR 600G' },
  { name: 'Ayçiçek yağı', size: '5 litre', startPrice: 248, monthlyDrift: 0.042, every: 2, raw: 'AYCICEK YAGI 5L' },
  { name: 'Ekmek, tam buğday', size: '500 g', startPrice: 18, monthlyDrift: 0.045, every: 1, raw: 'EKMEK TAM BUGDAY', qty: 8 },
  { name: 'Çay, siyah', size: '1 kg', startPrice: 198, monthlyDrift: 0.029, every: 3, raw: 'CAYKUR RIZE 1KG' },
  { name: 'Domates', size: 'kilogram', startPrice: 42, monthlyDrift: 0.03, every: 1, raw: 'DOMATES KG', qty: 1.24, seasonal: true },
  { name: 'Patates', size: 'kilogram', startPrice: 19.5, monthlyDrift: 0.028, every: 1, raw: 'PATATES KG', qty: 2.5, seasonal: true },
  { name: 'Tavuk göğsü', size: 'kilogram', startPrice: 118, monthlyDrift: 0.033, every: 1, raw: 'TAVUK GOGUS KG', qty: 1.1 },
  { name: 'Makarna', size: '500 g', startPrice: 14.5, monthlyDrift: 0.026, every: 2, raw: 'MAKARNA BURGU 500G', qty: 4 },
  { name: 'Yoğurt', size: '1 kg', startPrice: 52, monthlyDrift: 0.032, every: 1, raw: 'YOGURT 1KG' },
  { name: 'Şeker, toz', size: '1 kg', startPrice: 34, monthlyDrift: 0.024, every: 2, raw: 'TOZ SEKER 1KG' },
  { name: 'Deterjan, çamaşır', size: '3 litre', startPrice: 149, monthlyDrift: 0.027, every: 3, raw: 'CAMASIR DETERJANI 3L' },
];

const CHAINS = ['BIM', 'A101', 'MIGROS', 'SOK'];

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

async function main(): Promise<void> {
  console.log('Demo hesabı kuruluyor…');

  await query(`DELETE FROM users WHERE lower(email) = $1`, [DEMO_EMAIL]);
  const user = await one<{ id: string }>(
    `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
    [DEMO_EMAIL, 'Demo'],
  );

  const merchants = await query<{ id: string; chain_code: string }>(
    `SELECT id, chain_code FROM merchants WHERE chain_code = ANY($1)`,
    [CHAINS],
  );
  const products = await query<{ id: string; name: string; size_label: string }>(
    `SELECT id, name, size_label FROM canonical_products`,
  );
  const findProduct = (name: string, size: string): string => {
    const p = products.find((x) => x.name === name && x.size_label === size);
    if (!p) throw new Error(`Katalogda yok: ${name} ${size}. Önce seeds/catalog.sql yükle.`);
    return p.id;
  };

  let receiptCount = 0;
  let lineCount = 0;

  // 11 ay önceden bu aya. Her ay iki alışveriş.
  for (let monthsAgo = 11; monthsAgo >= 0; monthsAgo--) {
    for (const [trip, day] of [[0, 6], [1, 19]] as const) {
      const merchant = merchants[(monthsAgo * 2 + trip) % merchants.length]!;
      const lines: Array<{ productId: string; raw: string; qty: number; amount: number }> = [];

      for (const [i, item] of CATALOG.entries()) {
        // Seyrek alınan kalemler her fişte yok — endeksin boşluk doldurması
        // gerçek veride de devreye giriyor.
        if ((monthsAgo * 2 + trip + i) % item.every !== 0) continue;
        if (item.every > 1 && trip === 1) continue;

        const elapsed = 11 - monthsAgo;
        let unit = item.startPrice * Math.pow(1 + item.monthlyDrift, elapsed);

        // Mevsimsellik: yaz aylarında taze ürün ucuzluyor.
        if (item.seasonal) {
          const month = new Date();
          month.setMonth(month.getMonth() - monthsAgo);
          const m = month.getMonth() + 1;
          if (m >= 6 && m <= 9) unit *= 0.82;
        }
        // Market farkı ve küçük gürültü.
        const chainFactor =
          merchant.chain_code === 'MIGROS' ? 1.08
          : merchant.chain_code === 'BIM' ? 0.94
          : merchant.chain_code === 'SOK' ? 0.96
          : 1.0;
        unit *= chainFactor * (0.98 + ((monthsAgo * 7 + i * 13) % 5) / 100);

        const qty = item.qty ?? 1;
        lines.push({
          productId: findProduct(item.name, item.size),
          raw: item.raw,
          qty,
          amount: round2(unit * qty),
        });
      }
      if (!lines.length) continue;

      const date = new Date();
      date.setDate(1);
      date.setMonth(date.getMonth() - monthsAgo);
      date.setDate(day);
      const purchasedAt = date.toISOString().slice(0, 10);

      const receipt = await one<{ id: string }>(
        `INSERT INTO receipts (user_id, merchant_id, purchased_at, total_amount)
         VALUES ($1, $2, $3, $4) RETURNING id`,
        [user.id, merchant.id, purchasedAt, round2(lines.reduce((a, l) => a + l.amount, 0))],
      );
      receiptCount++;

      for (const [i, l] of lines.entries()) {
        // En son fişte iki satır bilerek "pending" bırakılıyor: uygulamadaki
        // "eşleşme?" akışının demo hesapta da görünmesi için.
        const pending = monthsAgo === 0 && trip === 1 && (i === 1 || i === 6);
        await query(
          `INSERT INTO receipt_lines
             (receipt_id, line_no, raw_text, quantity, line_amount,
              canonical_product_id, status, match_confidence)
           VALUES ($1, $2, $3, $4, $5, $6, $7::match_status, $8)`,
          [
            receipt.id, i + 1, l.raw, l.qty, l.amount,
            pending ? null : l.productId,
            pending ? 'pending' : 'auto',
            pending ? 0.62 : 1,
          ],
        );
        lineCount++;
      }
    }
  }

  await query(`SELECT refresh_user_index($1)`, [user.id]);

  const [head] = await query<{ change_pct: number; window_months: number }>(
    `SELECT change_pct, window_months FROM v_index_headline WHERE user_id = $1`,
    [user.id],
  );

  console.log(`  kullanıcı      ${DEMO_EMAIL}`);
  console.log(`  fiş            ${receiptCount}`);
  console.log(`  satır          ${lineCount}`);
  console.log(`  endeks         %${head?.change_pct} (${head?.window_months} aylık pencere)`);

  await pool.end();
}

main().catch(async (err) => {
  console.error(err);
  await pool.end();
  process.exit(1);
});
