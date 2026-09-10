/**
 * marketfiyati.org.tr istemcisi — zincirlerin yayımladığı güncel fiyatlar.
 *
 * TÜBİTAK BİLGEM'in, Ticaret Bakanlığı ve Merkez Bankası iş birliğiyle
 * yürüttüğü kamu hizmeti. Yedi zinciri kapsıyor ve her ürünün adını, markasını
 * ve BOYUNU yayımlıyor — yazarkasa fişinin basmadığı tek şeyi.
 *
 * Yayımlanmış bir API sözleşmesi YOK. Uç haber vermeden değişebilir, hız
 * sınırı bilinmiyor ve hizmet garantisi yok. Bu yüzden:
 *
 * - Çağrı yalnızca toplu çekim betiğinden yapılıyor, istek yolunda değil.
 *   Eşleştirme üçüncü bir tarafın ayakta olmasına bağlanamaz.
 * - Sonuçlar veritabanına yazılıyor, uygulama oradan okuyor.
 * - Kendini tanıtan bir user-agent gönderiliyor ve çağrılar arasında
 *   bekleniyor.
 */

/** Kaynaktaki zincir adı -> bizim merchants.chain_code. */
const CHAIN_CODES: Record<string, string> = {
  migros: 'MIGROS',
  a101: 'A101',
  bim: 'BIM',
  sok: 'SOK',
  carrefour: 'CARREFOURSA',
};

export type ReferenceItem = {
  /** Kaynaktaki ürün kimliği. */
  ref: string;
  title: string;
  brand: string | null;
  /** "400 GR", "1 LT", null olabiliyor. */
  sizeText: string | null;
  /** Kaynağın kendi kategorisi: "Süt", "Konserve", "Pet Shop". */
  mainCategory: string | null;
  /** chain_code -> fiyat. Yalnızca tanıdığımız zincirler. */
  prices: Map<string, number>;
  /** Kaynağın fiyatı indekslediği gün. */
  observedOn: string | null;
};

type RawDepot = {
  price?: number;
  marketAdi?: string;
  indexTime?: string;
};

type RawItem = {
  id?: string;
  title?: string;
  brand?: string | null;
  refinedVolumeOrWeight?: string | null;
  main_category?: string | null;
  productDepotInfoList?: RawDepot[];
};

const BASE = 'https://api.marketfiyati.org.tr/api/v2';

/**
 * Konum zorunlu — konumsuz istek 404 dönüyor. İstanbul merkezi ve geniş bir
 * yarıçap veriliyor: amaç bir mağaza bulmak değil, ülke çapında yayımlanan
 * fiyatı görmek.
 */
const KONUM = { latitude: 41.0082, longitude: 28.9784, distance: 100 };

/** "08.09.2026 12:14" -> "2026-09-08". Kaynak gün.ay.yıl yazıyor. */
function indexGunu(text: string | undefined): string | null {
  if (!text) return null;
  const m = /^(\d{2})\.(\d{2})\.(\d{4})/.exec(text.trim());
  return m ? `${m[3]}-${m[2]}-${m[1]}` : null;
}

export async function searchReference(
  keywords: string,
  size = 20,
  /** Testler ağa çıkmasın diye. [refreshOfficial] ile aynı dikiş. */
  fetchImpl: typeof fetch = fetch,
): Promise<ReferenceItem[]> {
  const res = await fetchImpl(`${BASE}/search`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      // Kendini tanıtmak, kamuya açık bir hizmete karşı asgari nezaket.
      'user-agent': 'Sepet/1.0 (kisisel enflasyon endeksi)',
    },
    body: JSON.stringify({ keywords, pages: 0, size, ...KONUM }),
  });

  if (!res.ok) {
    throw new Error(`marketfiyati ${res.status} — "${keywords}"`);
  }

  const body = (await res.json()) as { content?: RawItem[] };
  const out: ReferenceItem[] = [];

  for (const item of body.content ?? []) {
    if (!item.id || !item.title) continue;
    const prices = new Map<string, number>();
    let observedOn: string | null = null;

    for (const depot of item.productDepotInfoList ?? []) {
      const chain = CHAIN_CODES[depot.marketAdi ?? ''];
      const price = depot.price;
      if (!chain || typeof price !== 'number' || !(price > 0)) continue;
      // Aynı zincirin birden çok deposu gelirse en düşüğü: yayımlanan fiyat
      // olarak en az bir mağazada geçerli olanı tutuyoruz.
      const onceki = prices.get(chain);
      if (onceki === undefined || price < onceki) prices.set(chain, price);
      observedOn ??= indexGunu(depot.indexTime);
    }

    if (prices.size === 0) continue;

    out.push({
      ref: item.id,
      title: item.title,
      brand: item.brand ?? null,
      sizeText: item.refinedVolumeOrWeight ?? null,
      mainCategory: item.main_category ?? null,
      prices,
      observedOn,
    });
  }

  return out;
}
