import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { query } from '../db.js';

export const merchantsRouter = Router();
merchantsRouter.use(requireAuth);

/// Fiş kaydederken market seçimi için. Katalog gibi global.
merchantsRouter.get('/', async (_req, res) => {
  const rows = await query<{ id: string; name: string; chain_code: string }>(
    `SELECT id, name, chain_code FROM merchants ORDER BY name`,
  );
  res.json(
    rows.map((r) => ({ id: r.id, name: r.name, chainCode: r.chain_code })),
  );
});

/// Listede olmayan bir market ekler.
///
/// Liste zincirlerle sınırlıydı ve bu, fişi kaydetmenin önünde katı bir
/// duvardı: "Onur Market"ten alınan fiş hiçbir şekilde girilemiyordu —
/// eşleşmeyen bir kalem gibi bekleyemiyor, kaydın kendisi olmuyordu.
/// Oysa endeks için marketin kim olduğu sabit bir kimlik olması dışında
/// önemli değil; aynı ürünü nerede daha ucuza aldığını görmek için de
/// yerel marketlerin listede olması gerekiyor.
///
/// Aynı ad ikinci kez gönderilirse yenisi açılmıyor, mevcut olan dönüyor:
/// `chain_code` normalleştirilmiş addan üretiliyor ve tekil.
merchantsRouter.post('/', async (req: AuthedRequest, res) => {
  const name = String(req.body?.name ?? '').trim().replace(/\s+/g, ' ');
  if (name.length < 2 || name.length > 60) {
    res.status(400).json({ error: 'Market adı 2-60 karakter olmalı' });
    return;
  }

  const rows = await query<{ id: string; name: string; chain_code: string }>(
    `WITH yeni AS (
       INSERT INTO merchants (name, chain_code)
       VALUES ($1, replace(normalize_raw_text($1), ' ', '_'))
       ON CONFLICT (chain_code) DO NOTHING
       RETURNING id, name, chain_code
     )
     SELECT id, name, chain_code FROM yeni
     UNION ALL
     SELECT id, name, chain_code FROM merchants
      WHERE chain_code = replace(normalize_raw_text($1), ' ', '_')
     LIMIT 1`,
    [name],
  );

  const m = rows[0]!;
  res.status(201).json({ id: m.id, name: m.name, chainCode: m.chain_code });
});
