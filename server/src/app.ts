import express from 'express';
import { authRouter } from './routes/auth.js';
import { indexRouter } from './routes/index-routes.js';
import { merchantsRouter } from './routes/merchants.js';
import { productsRouter } from './routes/products.js';
import { receiptsRouter } from './routes/receipts.js';
import { query } from './db.js';

export function createApp() {
  const app = express();
  app.use(express.json({ limit: '256kb' }));

  /// Canlılık: süreç ayakta mı. Render dağıtımın başarılı sayılıp
  /// sayılmayacağına buna bakarak karar veriyor, o yüzden veritabanına
  /// DOKUNMUYOR — Neon ücretsiz katmanda 5 dakikada askıya alıyor ve soğuk
  /// başlatma ilk kontrolü zaman aşımına düşürüp dağıtımı öldürüyordu.
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  /// Hazırlık: veritabanı gerçekten erişilebilir mi. İzleme ve hata ayıklama
  /// için; dağıtım kararı buna bağlı değil.
  app.get('/health/db', async (_req, res) => {
    try {
      const started = Date.now();
      await query('SELECT 1');
      res.json({ ok: true, latencyMs: Date.now() - started });
    } catch (err) {
      res.status(503).json({
        ok: false,
        error: err instanceof Error ? err.message : 'Veritabanına ulaşılamadı',
      });
    }
  });

  app.use('/auth', authRouter);
  app.use('/index', indexRouter);
  app.use('/receipts', receiptsRouter);
  app.use('/products', productsRouter);
  app.use('/merchants', merchantsRouter);

  app.use((_req, res) => {
    res.status(404).json({ error: 'Bulunamadı' });
  });

  // Hata gövdesi istemciye iç ayrıntı sızdırmıyor; log tarafta duruyor.
  app.use(
    (
      err: Error,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      console.error('[sepet]', err);
      res.status(500).json({ error: 'Beklenmeyen bir hata oldu' });
    },
  );

  return app;
}
