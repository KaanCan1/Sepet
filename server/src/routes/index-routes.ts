import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { query } from '../db.js';

export const indexRouter = Router();
indexRouter.use(requireAuth);

/**
 * Ekran 01. Manşet + kendi serin + resmî seriler.
 *
 * 12 ay dolmamışsa yıllıklandırma yapılmaz: `windowMonths` gerçek pencereyi
 * söyler ve ekrandaki etiket ("SON 12 AY") ona göre yazılır.
 */
indexRouter.get('/', async (req: AuthedRequest, res) => {
  const userId = req.userId!;

  const [headline] = await query<{
    change_pct: number | null;
    window_months: number;
    current_month: string;
    covered_weight: number;
  }>(
    // to_char burada artık bir gereklilik değil, açık niyet: DATE
    // sütunlarının dizge dönmesi db.ts'teki tür çözümleyicisinde
    // garanti altında (saat dilimi kayması oradaki yorumda anlatılıyor).
    `SELECT change_pct, window_months, covered_weight,
            to_char(current_month, 'YYYY-MM-DD') AS current_month
       FROM v_index_headline WHERE user_id = $1`,
    [userId],
  );

  if (!headline) {
    // Resmî seri kullanıcının verisine bağlı değil; hiç fişi olmayan
    // hesapta da gönderiliyor. Eskiden boş dizi dönüyordu ve ilk açılışta
    // ekran tamamen boş kalıyordu — kullanıcı ne yapacağını göremiyordu.
    res.json({ headline: null, series: [], official: await officialSeries() });
    return;
  }

  const series = await query<{ month: string; level: number; mom_pct: number }>(
    `SELECT to_char(month, 'YYYY-MM-DD') AS month, level, mom_pct
       FROM v_index_series
      WHERE user_id = $1 ORDER BY month`,
    [userId],
  );

  // Geçen aya göre kaç puan oynadı — rozetteki sayı.
  const [delta] = await query<{ delta: number | null }>(
    `WITH h AS (SELECT current_month FROM v_index_headline WHERE user_id = $1)
     SELECT round(
              (SELECT level FROM index_levels
                WHERE user_id = $1 AND month = h.current_month)
              / nullif((SELECT level FROM index_levels
                         WHERE user_id = $1
                           AND month = h.current_month - interval '1 month'), 0)
              * 100 - 100, 1) AS delta
       FROM h`,
    [userId],
  );

  const official = await officialSeries();

  res.json({
    headline: {
      changePct: headline.change_pct,
      windowMonths: headline.window_months,
      month: headline.current_month,
      coveredWeight: headline.covered_weight,
      monthDeltaPoints: delta?.delta ?? null,
    },
    series: series.map((r) => ({
      month: r.month,
      level: r.level,
      momPct: r.mom_pct,
    })),
    official,
  });
});

/**
 * Son sepetin karşılaştırması: "aynı şeyleri daha ucuza görmüştün".
 *
 * Endeks iki FARKLI ayda fiş istiyor — bir fiyatın değiştiğini görmek için
 * onu iki kez görmek gerekiyor. Bu, uygulamanın ilk günlerinde kullanıcının
 * eline hiçbir şey geçmemesi demekti: ekran "bir ay daha lazım" yazıp
 * duruyordu. Oysa ikinci fişten itibaren söylenebilecek gerçek bir şey var
 * ve o zaman kaybı endeksi beklemiyor.
 *
 * Karşılaştırma GRUP + BOY üzerinden: "600 g beyaz peynir" raftaki gerçek
 * seçim, markası kimin olursa olsun. Alternatifin markası ve marketi
 * ekranda adıyla yazılıyor — kullanıcı neyle kıyaslandığını görmeden
 * "tasarruf" sayısına inanmak zorunda kalmasın.
 *
 * İki şey kasıtlı olarak dışarıda:
 *
 * - AYNI ürün + AYNI market: aradaki fark zamandan geliyor, seçimden değil.
 *   Onu tasarruf diye yazmak enflasyonu indirim gibi göstermek olurdu.
 * - 90 günden eski gözlem: iki yıl önceki fiyatla kıyaslamak da aynı hatanın
 *   daha büyüğü.
 */
indexRouter.get('/basket', async (req: AuthedRequest, res) => {
  const userId = req.userId!;

  const rows = await query<{
    receipt_id: string;
    merchant: string;
    name: string;
    amount: string;
    unit_price: string;
    best_name: string;
    best_merchant: string;
    best_unit_price: string;
    best_seen_on: string;
    best_amount: string;
  }>(
    `WITH son AS (
       -- En son fiş değil, GÖZLEMİ OLAN en son fiş. Yeni çekilmiş bir fişin
       -- kalemleri henüz eşleşmemiş olabiliyor; ona bağlanınca ekran, elde
       -- kıyaslanacak veri varken bile boş kalıyordu.
       SELECT r.id, r.merchant_id, r.purchased_at, m.name AS merchant
         FROM receipts r
         JOIN merchants m ON m.id = r.merchant_id
        WHERE r.user_id = $1
          AND EXISTS (
            SELECT 1 FROM receipt_lines l
              JOIN price_observations o ON o.receipt_line_id = l.id
             WHERE l.receipt_id = r.id AND NOT o.is_outlier
          )
        ORDER BY r.purchased_at DESC, r.created_at DESC
        LIMIT 1
     ),
     kalem AS (
       SELECT son.id AS receipt_id, son.merchant, son.merchant_id,
              son.purchased_at,
              o.canonical_product_id, o.unit_price, o.amount,
              c.group_id, c.size_value,
              c.display_name AS name, c.size_label
         FROM son
         JOIN receipt_lines l ON l.receipt_id = son.id
         JOIN price_observations o ON o.receipt_line_id = l.id
         JOIN v_canonical_products c ON c.id = o.canonical_product_id
        WHERE o.user_id = $1 AND NOT o.is_outlier
     )
     SELECT k.receipt_id, k.merchant, k.name, k.amount, k.unit_price,
            a.name AS best_name, a.merchant AS best_merchant,
            a.unit_price AS best_unit_price,
            to_char(a.observed_on, 'YYYY-MM-DD') AS best_seen_on,
            round(k.amount * a.unit_price / k.unit_price, 2) AS best_amount
       FROM kalem k
       JOIN LATERAL (
         SELECT o2.unit_price, o2.observed_on,
                c2.display_name AS name, m2.name AS merchant
           FROM price_observations o2
           JOIN v_canonical_products c2 ON c2.id = o2.canonical_product_id
           JOIN merchants m2 ON m2.id = o2.merchant_id
          WHERE o2.user_id = $1
            AND NOT o2.is_outlier
            AND c2.group_id = k.group_id
            AND c2.size_value = k.size_value
            AND o2.unit_price < k.unit_price
            AND o2.observed_on >= k.purchased_at - interval '90 days'
            -- Aynı ürünü aynı markette daha ucuza görmüş olmak bir seçim
            -- değil, zaman farkı. Tasarruf diye yazılamaz.
            AND (o2.merchant_id <> k.merchant_id
                 OR o2.canonical_product_id <> k.canonical_product_id)
          ORDER BY o2.unit_price
          LIMIT 1
       ) a ON true
      ORDER BY (k.amount - round(k.amount * a.unit_price / k.unit_price, 2)) DESC`,
    [userId],
  );

  if (!rows.length) {
    // "Karşılaştıracak bir şey yok" ile "hiç tasarruf yok" ayrı durumlar.
    // İstemci ikisini karıştırıp "0 TL kaybettin" yazmasın diye açıkça
    // söyleniyor.
    res.json({ comparable: false });
    return;
  }

  const items = rows.map((r) => ({
    // display_name marka + grup + boy; boy ayrıca gönderilmiyor.
    name: r.name,
    paid: Number(r.amount),
    unitPrice: Number(r.unit_price),
    bestName: r.best_name,
    bestMerchant: r.best_merchant,
    bestUnitPrice: Number(r.best_unit_price),
    // Kıyaslanan fiyatın tarihi: "bugün bu fiyata alırsın" demiyoruz.
    bestSeenOn: r.best_seen_on,
    bestPaid: Number(r.best_amount),
    saved: Number((Number(r.amount) - Number(r.best_amount)).toFixed(2)),
  }));

  const paid = items.reduce((a, i) => a + i.paid, 0);
  const best = items.reduce((a, i) => a + i.bestPaid, 0);

  res.json({
    comparable: true,
    receiptId: rows[0]!.receipt_id,
    merchant: rows[0]!.merchant,
    // Toplamlar yalnızca kıyaslanabilen kalemleri kapsıyor, fişin tamamını
    // değil. "Sepetin toplamı" demek yanlış olurdu.
    itemCount: items.length,
    paid: Number(paid.toFixed(2)),
    best: Number(best.toFixed(2)),
    saved: Number((paid - best).toFixed(2)),
    items,
  });
});

/** Ekran 04'ün alt kısmı: bu ay en çok zamlananlar. */
indexRouter.get('/movers', async (req: AuthedRequest, res) => {
  const rows = await query<{
    canonical_product_id: string;
    name: string;
    size_label: string;
    change_pct: number;
  }>(
    `SELECT canonical_product_id, name, size_label, change_pct
       FROM v_monthly_movers
      WHERE user_id = $1
        AND month = (SELECT max(month) FROM v_monthly_movers WHERE user_id = $1)
      ORDER BY change_pct DESC`,
    [req.userId],
  );
  res.json(
    rows.map((r) => ({
      productId: r.canonical_product_id,
      name: r.name,
      sizeLabel: r.size_label,
      changePct: r.change_pct,
    })),
  );
});

/**
 * Kategori kırılımı: hangi harcama kalemi kişisel enflasyonu sürüklüyor.
 *
 * Aynı zincirleme, kategoriye kısıtlanmış küme üzerinde ve ağırlıklar küme
 * içinde yeniden normalize edilerek hesaplanıyor. Genel endeksin alt
 * kalemleri değil, bağımsız serileri — biri diğerine toplanmıyor.
 */
indexRouter.get('/by-category', async (req: AuthedRequest, res) => {
  // Ay SQL'de metne çevriliyor. Bu ekranda bir kez ayın 1'i bir önceki ayın
  // 31'ine kaymış ve Ağustos seviyesi "Temmuz" diye etiketlenmişti; kayma
  // artık db.ts'teki DATE çözümleyicisiyle kaynağında kapalı, buradaki
  // to_char niyeti görünür tutuyor.
  const rows = await query<{
    category_id: string;
    category_code: string;
    category_name: string;
    month: string;
    level: number;
    covered_weight: number;
  }>(
    `SELECT category_id, category_code, category_name,
            to_char(month, 'YYYY-MM-DD') AS month,
            level, covered_weight
       FROM v_index_by_category
      WHERE user_id = $1
      ORDER BY category_name, month`,
    [req.userId],
  );

  // Kategori başına tek nesne; seri içinde aylar sırada.
  const byCategory = new Map<string, {
    categoryId: string;
    code: string;
    name: string;
    latestLevel: number;
    series: Array<{ month: string; level: number; coveredWeight: number }>;
  }>();

  for (const r of rows) {
    const month = r.month;
    let entry = byCategory.get(r.category_id);
    if (!entry) {
      entry = {
        categoryId: r.category_id,
        code: r.category_code,
        name: r.category_name,
        latestLevel: r.level,
        series: [],
      };
      byCategory.set(r.category_id, entry);
    }
    entry.series.push({ month, level: r.level, coveredWeight: r.covered_weight });
    entry.latestLevel = r.level;
  }

  res.json(
    [...byCategory.values()].sort((a, b) => b.latestLevel - a.latestLevel),
  );
});

/**
 * Marka kırılımı. Yalnızca markalı kalemler: kasada tartılan sebzenin
 * markası yok, uydurulmuyor — o kalemler bu seride hiç yer almıyor.
 */
indexRouter.get('/by-brand', async (req: AuthedRequest, res) => {
  const rows = await query<{
    brand_id: string;
    brand_name: string;
    month: string;
    level: number;
    covered_weight: number;
  }>(
    `SELECT brand_id, brand_name,
            to_char(month, 'YYYY-MM-DD') AS month,
            level, covered_weight
       FROM v_index_by_brand
      WHERE user_id = $1
      ORDER BY brand_name, month`,
    [req.userId],
  );

  const byBrand = new Map<string, {
    brandId: string;
    name: string;
    latestLevel: number;
    series: Array<{ month: string; level: number; coveredWeight: number }>;
  }>();

  for (const r of rows) {
    const month = r.month;
    let entry = byBrand.get(r.brand_id);
    if (!entry) {
      entry = { brandId: r.brand_id, name: r.brand_name, latestLevel: r.level, series: [] };
      byBrand.set(r.brand_id, entry);
    }
    entry.series.push({ month, level: r.level, coveredWeight: r.covered_weight });
    entry.latestLevel = r.level;
  }

  res.json([...byBrand.values()].sort((a, b) => b.latestLevel - a.latestLevel));
});

/// Karşılaştırma serileri ve her birinin en son girilmiş yıllık değişimi.
///
/// Kullanıcıdan bağımsız: endeksi olmayan hesapta da gönderiliyor, çünkü
/// TÜİK sayısı o hesabın fişlerine bağlı değil.
async function officialSeries(): Promise<
  Array<{
    code: string;
    publisher: string;
    name: string;
    isOfficial: boolean;
    yoyPct: number | null;
    levels: Array<{ month: string; level: number }>;
  }>
> {
  // Alan adları BURADA çevriliyor, çağıranda değil. İlk yazışta çevirme
  // yalnızca dolu daldaydı; boş dalda ham satırlar gidiyor ve uygulama
  // yoyPct yerine yoy_pct görüp değeri null sanıyordu — TÜİK sayısı
  // girilmiş olmasına rağmen ekranda "—" çıkıyordu.
  const rows = await query<{
    code: string;
    publisher: string;
    name: string;
    is_official: boolean;
    yoy_pct: number | null;
  }>(
    `SELECT DISTINCT ON (s.id)
            s.code, s.publisher, s.name, s.is_official, l.yoy_pct
       FROM official_series s
       LEFT JOIN official_index_levels l ON l.series_id = s.id
      ORDER BY s.id, l.month DESC NULLS LAST`,
  );
  // Grafikteki kesikli çizgi için ay ay seviye.
  //
  // Manşetteki yıllık yüzde buraya yetmiyor: yıllık değişim serisinden
  // aylık bir yol geri türetilemez. Seviye ise mutlak olarak da
  // gösterilmiyor — istemci iki seriyi ortak bir aya 100'lüyor, böylece
  // TÜİK'in taban yılı ekranda hiç görünmüyor ve iki çizgi "başladığın
  // aydan bugüne" sorusunu aynı ölçekte cevaplıyor.
  //
  // Yalnızca seviyesi olan aylar dönüyor. Elle girilen aylarda yüzde var
  // ama seviye yok; o aylar çizgide boşluk bırakıyor, uydurulmuyor.
  const levelRows = await query<{
    code: string;
    month: string;
    level: number;
  }>(
    `SELECT s.code, to_char(l.month, 'YYYY-MM-DD') AS month, l.level
       FROM official_index_levels l
       JOIN official_series s ON s.id = l.series_id
      WHERE l.level IS NOT NULL
      ORDER BY s.code, l.month`,
  );

  const byCode = new Map<string, Array<{ month: string; level: number }>>();
  for (const r of levelRows) {
    const list = byCode.get(r.code) ?? [];
    list.push({ month: r.month, level: r.level });
    byCode.set(r.code, list);
  }

  return rows.map((r) => ({
    code: r.code,
    publisher: r.publisher,
    name: r.name,
    isOfficial: r.is_official,
    yoyPct: r.yoy_pct,
    levels: byCode.get(r.code) ?? [],
  }));
}
