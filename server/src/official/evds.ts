/**
 * TCMB EVDS istemcisi — TÜİK TÜFE serisini resmî kanaldan çeker.
 *
 * Neden TCMB: TÜİK'in kendi veri portalı otomatik erişimde yönlendirmeye
 * düşüyor, MEDAS oturum tabanlı bir arayüz. TÜFE'yi makine okunur biçimde
 * dağıtan resmî yer TCMB'nin Elektronik Veri Dağıtım Sistemi.
 *
 * Sözleşme belgelenmemiş olduğu için uygulamanın kendi paketinden çıkarıldı
 * ve gerçek anahtarla doğrulandı. Üç ayrıntı pahalıya mal oldu:
 *
 *   • Eski evds2/service/evds adresi kapanmış, evds3'e yönleniyor.
 *   • Anahtar sorgu değil BAŞLIK: `key: ...`.
 *   • ozelFormuller BOŞ DİZİ olmak zorunda; null verilince sunucu 500 dönüyor.
 *
 * Seri kodu TP.FE25.OKTG01 — "Tüketici Fiyat Endeksi (Genel)", 2025=100.
 * Eski TP.FE.OKTG01 arşiv; ona bakan bir kod sessizce donmuş veri okurdu.
 */

const BASE = 'https://evds3.tcmb.gov.tr/igmevdsms-dis';

/** TÜFE genel endeksi, aylık. */
export const CPI_SERIES = 'TP.FE25.OKTG01';

/** Bir ayın endeks seviyesi. */
export interface Level {
  /** YYYY-MM-01 */
  month: string;
  level: number;
}

/** EVDS tarihi "07-2026" biçiminde veriyor. */
function toMonth(tarih: string): string | null {
  const m = /^(\d{2})-(\d{4})$/.exec(tarih);
  return m ? `${m[2]}-${m[1]}-01` : null;
}

function ddmmyyyy(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getDate())}-${p(d.getMonth() + 1)}-${d.getFullYear()}`;
}

/**
 * Seviyelerden yıllık değişim üretir.
 *
 * Seviye değil yüzde saklıyoruz ama seviyeden hesaplamak zorundayız: EVDS
 * bu seri için yıllık değişimi ayrı bir seri olarak veriyor ve taban yılı
 * değiştiğinde (2003=100 → 2025=100) o seri kopuyor. Aynı serinin kendi
 * içinde oranlamak taban değişiminden etkilenmiyor.
 *
 * On iki ay öncesi elde yoksa o ay atlanıyor — uydurulmuyor.
 */
export function yearlyChanges(
  levels: Level[],
): Array<{ month: string; yoyPct: number }> {
  const byMonth = new Map(levels.map((l) => [l.month, l.level]));
  const out: Array<{ month: string; yoyPct: number }> = [];

  for (const { month, level } of levels) {
    const [y, m] = month.split('-');
    const prev = `${Number(y) - 1}-${m}-01`;
    const before = byMonth.get(prev);
    if (before === undefined || before === 0) continue;
    out.push({
      month,
      // İki ondalık: TÜİK de bu hassasiyette açıklıyor.
      yoyPct: Math.round((level / before - 1) * 10000) / 100,
    });
  }
  return out;
}

/** EVDS'ten ham seviyeleri çeker. */
export async function fetchLevels(options: {
  apiKey: string;
  /** Kaç ay geriye. Yıllık değişim için en az 13 gerekiyor. */
  months?: number;
  fetchImpl?: typeof fetch;
}): Promise<Level[]> {
  const months = options.months ?? 26;
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - months, 1);
  const doFetch = options.fetchImpl ?? fetch;

  const res = await doFetch(`${BASE}/fe`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', key: options.apiKey },
    body: JSON.stringify({
      type: 'json',
      series: CPI_SERIES,
      aggregationTypes: 'avg',
      formulas: '0',
      startDate: ddmmyyyy(start),
      endDate: ddmmyyyy(now),
      frequency: '5',
      decimalSeperator: '.',
      decimal: '2',
      dateFormat: '1',
      lang: 'TR',
      yon: 0,
      sira: 0,
      // Boş dizi şart. null verilince EVDS 500 dönüyor.
      ozelFormuller: [],
      isRaporSayfasi: false,
      groupSeperator: true,
    }),
  });

  if (!res.ok) {
    throw new Error(`EVDS ${res.status}: seri çekilemedi`);
  }

  const body = (await res.json()) as {
    items?: Array<Record<string, unknown>>;
  };

  // Alan adı seri kodundan türüyor: TP.FE25.OKTG01 → TP_FE25_OKTG01
  const field = CPI_SERIES.replaceAll('.', '_');
  const levels: Level[] = [];

  for (const item of body.items ?? []) {
    const month = toMonth(String(item.Tarih ?? ''));
    const raw = item[field];
    if (month === null || raw === null || raw === undefined || raw === '') {
      continue;
    }
    const level = Number(raw);
    if (Number.isFinite(level)) levels.push({ month, level });
  }
  return levels;
}
