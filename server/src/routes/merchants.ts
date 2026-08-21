import { Router } from 'express';
import { requireAuth } from '../auth.js';
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
