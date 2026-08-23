/**
 * Demo hesabı: 12 aylık fiş geçmişi.
 *
 * İki işe yarıyor. Biri geliştirme — Flutter'ı gerçek veriye bağlarken
 * gösterecek bir şey olsun. Diğeri App Store incelemesi: boş kabuk gönderilen
 * uygulamalar "minimum functionality" gerekçesiyle geri dönüyor, inceleme
 * notuna dolu bir demo hesabın bilgileri yazılmalı.
 *
 * FİYATLAR GERÇEK DEĞİL. Market sitelerinden fiyat çekilmiyor: Migros arama
 * sayfası fiyatı JavaScript'le basıyor, A101 otomatik erişime 403 veriyor.
 * Daha önemlisi rafta gördüğümüz fiyatın endekse girmemesi gerekiyor —
 * uygulamanın iddiası "senin fişinden senin enflasyonun", kullanıcının
 * ödemediği bir fiyat hesaba karışırsa sayı iddia ettiği şey olmaktan çıkar.
 * Aşağıdaki değerler 2026 ortası için makul büyüklükte tahminlerdir ve
 * yalnızca demo hesabını doldurur.
 */
import { one, pool, query } from '../src/db.js';

// Varsayılan demo hesabı; farklı bir adres için:  npm run seed -- ad@ornek.com
const DEMO_EMAIL = process.argv[2] ?? 'demo@sepet.app';

type Item = {
  group: string;
  /** null = markasız (kasada tartılan sebze, fırın ekmeği). */
  brand: string | null;
  size: string;
  /** Bugünkü paket fiyatı. Geçmiş buradan geriye doğru türetiliyor. */
  priceNow: number;
  /** Aylık artış oranı. 0,03 → yılda ~%42. */
  drift: number;
  /** Kaç ayda bir alınıyor. 1 = her ay. */
  every: number;
  /** Fişte görünen ham metin — alias öğrenmesi bunun üzerinden. */
  raw: string;
  qty?: number;
  /** Taze ürün: yaz aylarında ucuzluyor. */
  seasonal?: boolean;
};

// Aynı grupta birden çok marka bilerek var: marka bazlı kırılımın
// gösterecek bir şeyi olsun. 1,5 kg yoğurt üç markada üç fiyat.
const BASKET: Item[] = [
  // Süt ürünleri
  { group: 'Süt, tam yağlı', brand: 'Sütaş', size: '1 litre', priceNow: 52, drift: 0.031, every: 1, raw: 'SUTAS TAM YAGLI SUT 1L', qty: 3 },
  { group: 'Süt, tam yağlı', brand: 'Torku', size: '1 litre', priceNow: 48, drift: 0.029, every: 2, raw: 'TORKU SUT 1L', qty: 2 },
  { group: 'Yoğurt', brand: 'Sütaş', size: '1,5 kg', priceNow: 155, drift: 0.032, every: 1, raw: 'SUTAS YOGURT 1.5KG' },
  { group: 'Yoğurt', brand: 'Eker', size: '1,5 kg', priceNow: 165, drift: 0.036, every: 2, raw: 'EKER YOGURT 1500 GR' },
  { group: 'Yoğurt', brand: 'Pınar', size: '1,5 kg', priceNow: 158, drift: 0.030, every: 3, raw: 'PINAR YOGURT 1.5 KG' },
  { group: 'Beyaz peynir', brand: 'Sütaş', size: '600 g', priceNow: 285, drift: 0.035, every: 1, raw: 'SUTAS BEYAZ PEYNIR 600G' },
  { group: 'Beyaz peynir', brand: 'Tahsildaroğlu', size: '600 g', priceNow: 320, drift: 0.033, every: 3, raw: 'TAHSILDAROGLU EZINE 600 G' },
  { group: 'Kaşar peyniri', brand: 'Muratbey', size: '350 g', priceNow: 205, drift: 0.034, every: 2, raw: 'MURATBEY KASAR 350G' },
  { group: 'Tereyağı', brand: 'Sütaş', size: '250 g', priceNow: 195, drift: 0.030, every: 2, raw: 'SUTAS TEREYAG 250 GR' },
  { group: 'Yumurta', brand: null, size: "30'lu", priceNow: 235, drift: 0.037, every: 1, raw: 'YUMURTA 30LU' },
  { group: 'Ayran', brand: 'Sütaş', size: '1 litre', priceNow: 46, drift: 0.028, every: 1, raw: 'SUTAS AYRAN 1L', qty: 2 },

  // Yağ
  { group: 'Ayçiçek yağı', brand: 'Yudum', size: '5 litre', priceNow: 495, drift: 0.038, every: 2, raw: 'YUDUM AYCICEK YAGI 5L' },
  { group: 'Ayçiçek yağı', brand: 'Orkide', size: '5 litre', priceNow: 505, drift: 0.040, every: 4, raw: 'ORKIDE AYCICEK 5 LT' },
  { group: 'Zeytinyağı', brand: 'Komili', size: '1 litre', priceNow: 385, drift: 0.026, every: 3, raw: 'KOMILI RIVIERA 1L' },

  // Tahıl ve bakliyat
  { group: 'Ekmek, tam buğday', brand: null, size: '500 g', priceNow: 32, drift: 0.042, every: 1, raw: 'TAM BUGDAY EKMEK', qty: 8 },
  { group: 'Makarna, burgu', brand: 'Filiz', size: '500 g', priceNow: 27, drift: 0.025, every: 1, raw: 'FILIZ BURGU MAKARNA 500G', qty: 4 },
  { group: 'Makarna, burgu', brand: 'Nuhun Ankara', size: '500 g', priceNow: 29, drift: 0.027, every: 3, raw: 'NUHUN ANKARA MAKARNA 500 G', qty: 2 },
  { group: 'Pirinç, baldo', brand: 'Reis', size: '1 kg', priceNow: 115, drift: 0.028, every: 2, raw: 'REIS BALDO PIRINC 1KG' },
  { group: 'Bulgur, pilavlık', brand: 'Duru', size: '1 kg', priceNow: 68, drift: 0.024, every: 3, raw: 'DURU PILAVLIK BULGUR 1KG' },
  { group: 'Mercimek, kırmızı', brand: 'Yayla', size: '1 kg', priceNow: 92, drift: 0.030, every: 3, raw: 'YAYLA KIRMIZI MERCIMEK 1 KG' },
  { group: 'Un, buğday', brand: 'Sinangil', size: '2 kg', priceNow: 78, drift: 0.026, every: 4, raw: 'SINANGIL UN 2KG' },

  // Et
  { group: 'Tavuk göğsü', brand: 'Banvit', size: 'kilogram', priceNow: 235, drift: 0.033, every: 1, raw: 'BANVIT TAVUK GOGUS KG', qty: 1.1 },
  { group: 'Tavuk göğsü', brand: 'Şenpiliç', size: 'kilogram', priceNow: 228, drift: 0.031, every: 2, raw: 'SENPILIC TAVUK GOGUS', qty: 0.95 },
  { group: 'Kıyma, dana', brand: null, size: 'kilogram', priceNow: 720, drift: 0.034, every: 1, raw: 'DANA KIYMA KG', qty: 0.6 },

  // Sebze ve meyve — markasız, kasada tartılıyor
  { group: 'Domates', brand: null, size: 'kilogram', priceNow: 62, drift: 0.030, every: 1, raw: 'DOMATES KG', qty: 1.24, seasonal: true },
  { group: 'Salatalık', brand: null, size: 'kilogram', priceNow: 48, drift: 0.029, every: 1, raw: 'SALATALIK KG', qty: 0.8, seasonal: true },
  { group: 'Soğan, kuru', brand: null, size: 'kilogram', priceNow: 32, drift: 0.031, every: 1, raw: 'KURU SOGAN KG', qty: 2.0, seasonal: true },
  { group: 'Patates', brand: null, size: 'kilogram', priceNow: 34, drift: 0.028, every: 1, raw: 'PATATES KG', qty: 2.5, seasonal: true },
  { group: 'Biber, sivri', brand: null, size: 'kilogram', priceNow: 78, drift: 0.032, every: 2, raw: 'SIVRI BIBER KG', qty: 0.4, seasonal: true },
  { group: 'Elma', brand: null, size: 'kilogram', priceNow: 58, drift: 0.027, every: 1, raw: 'ELMA STARKING KG', qty: 1.5, seasonal: true },
  { group: 'Muz', brand: null, size: 'kilogram', priceNow: 95, drift: 0.025, every: 1, raw: 'MUZ ITHAL KG', qty: 1.0 },

  // İçecek ve kahvaltılık
  { group: 'Çay, siyah', brand: 'Çaykur', size: '1 kg', priceNow: 395, drift: 0.029, every: 3, raw: 'CAYKUR RIZE TURIST 1KG' },
  { group: 'Çay, siyah', brand: 'Doğuş', size: '1 kg', priceNow: 375, drift: 0.031, every: 6, raw: 'DOGUS KARADENIZ CAY 1000 GR' },
  { group: 'Türk kahvesi', brand: 'Kurukahveci Mehmet Efendi', size: '250 g', priceNow: 165, drift: 0.033, every: 3, raw: 'MEHMET EFENDI TURK KAHVESI 250G' },
  { group: 'Şeker, toz', brand: 'Balküpü', size: '1 kg', priceNow: 62, drift: 0.023, every: 2, raw: 'BALKUPU TOZ SEKER 1KG' },
  { group: 'Salça, domates', brand: 'Tat', size: '700 g', priceNow: 118, drift: 0.030, every: 3, raw: 'TAT DOMATES SALCASI 700G' },
  { group: 'Fındık kreması', brand: 'Sarelle', size: '350 g', priceNow: 135, drift: 0.028, every: 3, raw: 'SARELLE FINDIK KREMASI 350 G' },
  { group: 'Su, doğal kaynak', brand: 'Erikli', size: '5 litre', priceNow: 42, drift: 0.026, every: 1, raw: 'ERIKLI SU 5L', qty: 4 },
  { group: 'Gazlı içecek, kola', brand: 'Coca-Cola', size: '2,5 litre', priceNow: 78, drift: 0.024, every: 2, raw: 'COCA COLA 2.5 LT' },

  // Temizlik ve bakım
  { group: 'Deterjan, çamaşır', brand: 'Omo', size: '3 litre', priceNow: 315, drift: 0.027, every: 3, raw: 'OMO SIVI DETERJAN 3L' },
  { group: 'Deterjan, çamaşır', brand: 'Ariel', size: '3 litre', priceNow: 345, drift: 0.029, every: 6, raw: 'ARIEL SIVI 3 LT' },
  { group: 'Bulaşık deterjanı', brand: 'Fairy', size: '1,3 litre', priceNow: 185, drift: 0.026, every: 3, raw: 'FAIRY BULASIK 1300ML' },
  { group: 'Kağıt havlu', brand: 'Selpak', size: "8'li", priceNow: 165, drift: 0.028, every: 2, raw: 'SELPAK KAGIT HAVLU 8LI' },
  { group: 'Tuvalet kağıdı', brand: 'Selpak', size: "16'lı", priceNow: 195, drift: 0.027, every: 3, raw: 'SELPAK TUVALET KAGIDI 16LI' },
  { group: 'Şampuan', brand: 'Elidor', size: '500 mL', priceNow: 145, drift: 0.025, every: 4, raw: 'ELIDOR SAMPUAN 500ML' },
  { group: 'Diş macunu', brand: 'Colgate', size: '75 mL', priceNow: 78, drift: 0.026, every: 4, raw: 'COLGATE DIS MACUNU 75ML' },
];

const CHAINS = ['BIM', 'A101', 'MIGROS', 'SOK'];
const MONTHS = 11; // 11 ay öncesinden bugüne

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

/** Zincir bazlı fiyat seviyesi farkı. İndirim marketleri ucuz. */
function chainFactor(code: string): number {
  switch (code) {
    case 'MIGROS': return 1.08;
    case 'CARREFOURSA': return 1.05;
    case 'BIM': return 0.94;
    case 'SOK': return 0.96;
    default: return 1.0;
  }
}

async function main(): Promise<void> {
  console.log('Demo hesabı kuruluyor…');

  await query(`DELETE FROM users WHERE lower(email) = $1`, [DEMO_EMAIL]);
  const user = await one<{ id: string }>(
    `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
    [DEMO_EMAIL, 'Demo'],
  );

  const merchants = await query<{ id: string; chain_code: string }>(
    `SELECT id, chain_code FROM merchants WHERE chain_code = ANY($1) ORDER BY chain_code`,
    [CHAINS],
  );

  const products = await query<{
    id: string; group_name: string; brand_name: string | null; size_label: string;
  }>(`SELECT id, group_name, brand_name, size_label FROM v_canonical_products`);

  const findProduct = (it: Item): string => {
    const p = products.find(
      (x) => x.group_name === it.group
          && x.size_label === it.size
          && (x.brand_name ?? null) === it.brand,
    );
    if (!p) {
      throw new Error(
        `Katalogda yok: ${it.brand ?? '(markasız)'} ${it.group} ${it.size}. ` +
        `Önce seeds/catalog.sql yükle.`,
      );
    }
    return p.id;
  };

  let receiptCount = 0;
  let lineCount = 0;

  for (let monthsAgo = MONTHS; monthsAgo >= 0; monthsAgo--) {
    for (const [trip, day] of [[0, 6], [1, 19]] as const) {
      const merchant = merchants[(monthsAgo * 2 + trip) % merchants.length]!;
      const lines: Array<{ productId: string; raw: string; qty: number; amount: number }> = [];

      for (const [i, item] of BASKET.entries()) {
        // Seyrek alınan kalemler her fişte yok — endeksin boşluk doldurması
        // gerçek veride de devreye giriyor.
        if ((monthsAgo * 2 + trip + i) % item.every !== 0) continue;
        if (item.every > 1 && trip === 1) continue;

        // priceNow bugünün fiyatı; geçmişe doğru drift kadar geri sarılıyor.
        let unit = item.priceNow / Math.pow(1 + item.drift, monthsAgo);

        if (item.seasonal) {
          const month = new Date();
          month.setDate(1);
          month.setMonth(month.getMonth() - monthsAgo);
          const m = month.getMonth() + 1;
          if (m >= 6 && m <= 9) unit *= 0.82;
        }

        // Zincir farkı ve küçük, ama tekrar üretilebilir gürültü.
        unit *= chainFactor(merchant.chain_code) * (0.98 + ((monthsAgo * 7 + i * 13) % 5) / 100);

        const qty = item.qty ?? 1;
        lines.push({ productId: findProduct(item), raw: item.raw, qty, amount: round2(unit * qty) });
      }
      if (!lines.length) continue;

      const date = new Date();
      date.setDate(1);
      date.setMonth(date.getMonth() - monthsAgo);
      date.setDate(day);
      // Bu ayın henüz gelmemiş günü için fiş üretme.
      if (date > new Date()) continue;
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
        const pending = monthsAgo === 0 && (i === 1 || i === 6);
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

  // Bir yıldır kullanılan hesapta bu eşleşmeler çoktan onaylanmış olurdu.
  // Alias'lar market bazlı: aynı ham metin farklı zincirde farklı ürün olabilir.
  let aliasCount = 0;
  for (const merchant of merchants) {
    for (const item of BASKET) {
      await query(
        `INSERT INTO product_aliases (merchant_id, raw_text_normalized, canonical_product_id)
         VALUES ($1, normalize_raw_text($2), $3)
         ON CONFLICT (merchant_id, raw_text_normalized) DO NOTHING`,
        [merchant.id, item.raw, findProduct(item)],
      );
      aliasCount++;
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
  console.log(`  eşleşme kaydı  ${aliasCount}`);
  console.log(`  endeks         %${head?.change_pct} (${head?.window_months} aylık pencere)`);
  console.log('  not            fiyatlar tahmindir, market sitelerinden çekilmiyor');

  await pool.end();
}

main().catch(async (err) => {
  console.error(err);
  await pool.end();
  process.exit(1);
});
