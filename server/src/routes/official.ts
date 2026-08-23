import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { one, query } from '../db.js';

export const officialRouter = Router();
officialRouter.use(requireAuth);

/// Resmî ve bağımsız enflasyon serileri: TÜİK TÜFE ve ENAG E-TÜFE.
///
/// Neden elle giriliyor: ikisinin de makine okunur, güvenilir bir akışı yok.
/// TÜİK'in veri portalı otomatik erişimde yönlendirmeye düşüyor, MEDAS oturum
/// tabanlı bir arayüz, ENAG'ın sitesi bu ortamdan hiç açılmıyor. Sayfa
/// kazımak kullanım koşullarına takılır ve her tasarım değişikliğinde kırılır.
///
/// Uydurmak seçenek değildi: uygulamanın bütün iddiası ölçülen sayıların
/// gerçek olması. Ekranda "—" durması, yanlış bir sayı durmasından iyi.
/// Ayda bir, iki sayı — elle girmek makul.
///
/// Seriler kullanıcıya değil herkese ait: aynı TÜFE herkes için aynı. Giriş
/// yapmış herkes yazabiliyor; tek kullanıcılı bu aşamada sorun değil, çok
/// kullanıcıya açılırken yetki kontrolü gerekecek.

/// Seriler ve girilmiş bütün aylar.
officialRouter.get('/', async (_req: AuthedRequest, res) => {
  const rows = await query<{
    code: string;
    publisher: string;
    name: string;
    is_official: boolean;
    month: string | null;
    yoy_pct: number | null;
  }>(
    `SELECT s.code, s.publisher, s.name, s.is_official,
            to_char(l.month, 'YYYY-MM-DD') AS month,
            l.yoy_pct
       FROM official_series s
       LEFT JOIN official_index_levels l ON l.series_id = s.id
      ORDER BY s.is_official DESC, s.code, l.month DESC`,
  );

  const bySeries = new Map<string, {
    code: string;
    publisher: string;
    name: string;
    isOfficial: boolean;
    entries: Array<{ month: string; yoyPct: number }>;
  }>();

  for (const r of rows) {
    let entry = bySeries.get(r.code);
    if (!entry) {
      entry = {
        code: r.code,
        publisher: r.publisher,
        name: r.name,
        isOfficial: r.is_official,
        entries: [],
      };
      bySeries.set(r.code, entry);
    }
    // LEFT JOIN: hiç girdisi olmayan seri de listede görünüyor.
    if (r.month !== null && r.yoy_pct !== null) {
      entry.entries.push({ month: r.month, yoyPct: r.yoy_pct });
    }
  }

  res.json([...bySeries.values()]);
});

/// Bir ayın yıllık değişimini yazar ya da düzeltir.
///
/// Seviye değil yıllık yüzde tutuluyor: kaynaklar zaten yıllık değişimi
/// açıklıyor ve seviyeden yeniden hesaplamak yuvarlama farkı üretiyor.
officialRouter.put('/:code/:month', async (req: AuthedRequest, res) => {
  const { code, month } = req.params;
  const yoyPct = Number(req.body?.yoyPct);

  if (!Number.isFinite(yoyPct)) {
    res.status(400).json({ error: 'Yıllık değişim sayı olmalı' });
    return;
  }
  // Enflasyon eksi de olabilir ama bu aralığın dışı veri girişi hatasıdır.
  if (yoyPct < -100 || yoyPct > 1000) {
    res.status(400).json({ error: 'Yıllık değişim −100 ile 1000 arasında olmalı' });
    return;
  }
  if (!/^\d{4}-\d{2}-01$/.test(month ?? '')) {
    res.status(400).json({ error: 'Ay YYYY-MM-01 biçiminde olmalı' });
    return;
  }

  const series = await query<{ id: string }>(
    `SELECT id FROM official_series WHERE code = $1`,
    [code],
  );
  if (series.length === 0) {
    res.status(404).json({ error: 'Böyle bir seri yok' });
    return;
  }

  const saved = await one<{ month: string; yoy_pct: number }>(
    `INSERT INTO official_index_levels (series_id, month, yoy_pct, published_at)
     VALUES ($1, $2::date, $3, current_date)
     ON CONFLICT (series_id, month)
     DO UPDATE SET yoy_pct = EXCLUDED.yoy_pct,
                   published_at = EXCLUDED.published_at
     RETURNING to_char(month, 'YYYY-MM-DD') AS month, yoy_pct`,
    [series[0]!.id, month, yoyPct],
  );

  res.json({ month: saved.month, yoyPct: saved.yoy_pct });
});

/// Yanlış girilen bir ayı siler.
officialRouter.delete('/:code/:month', async (req: AuthedRequest, res) => {
  const { code, month } = req.params;
  const { length } = await query(
    `DELETE FROM official_index_levels l
      USING official_series s
      WHERE l.series_id = s.id AND s.code = $1 AND l.month = $2::date
      RETURNING l.month`,
    [code, month],
  );
  if (length === 0) {
    res.status(404).json({ error: 'Böyle bir kayıt yok' });
    return;
  }
  res.json({ ok: true });
});
