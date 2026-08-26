import express from 'express';
import { accountRouter } from './routes/account.js';
import { authRouter } from './routes/auth.js';
import { officialRouter } from './routes/official.js';
import { indexRouter } from './routes/index-routes.js';
import { merchantsRouter } from './routes/merchants.js';
import { productsRouter } from './routes/products.js';
import { receiptsRouter } from './routes/receipts.js';
import { query } from './db.js';
import { env } from './env.js';

export function createApp() {
  const app = express();
  app.use(express.json({ limit: '256kb' }));

  /// Canlılık: süreç ayakta mı. Render dağıtımın başarılı sayılıp
  /// sayılmayacağına buna bakarak karar veriyor, o yüzden veritabanına
  /// DOKUNMUYOR — Neon ücretsiz katmanda 5 dakikada askıya alıyor ve soğuk
  /// başlatma ilk kontrolü zaman aşımına düşürüp dağıtımı öldürüyordu.
  ///
  /// commit buraya bu yüzden konabiliyor: ortam değişkeninden geliyor,
  /// sorgu gerektirmiyor. "Yeni kod canlıda mı?" tek istekle cevaplanıyor.
  app.get('/health', (_req, res) => {
    res.json({ ok: true, commit: env.commit });
  });

  /// Hazırlık: veritabanı gerçekten erişilebilir mi. İzleme ve hata ayıklama
  /// için; dağıtım kararı buna bağlı değil.
  ///
  /// Katalog sayıları BURADA, /health'te değil. Oraya koymak canlılık
  /// kontrolünü veritabanına bağlardı ve tam da kaçınılan şeyi geri
  /// getirirdi: Neon askıdayken dağıtım ölür.
  ///
  /// Sayılar bir dağıtımın tohumu gerçekten uygulayıp uygulamadığını
  /// söylüyor: migration geçip katalog yüklenmediyse commit yeni görünür
  /// ama ürün sayısı eski kalır.
  app.get('/health/db', async (_req, res) => {
    try {
      const started = Date.now();
      const [k] = await query<{ products: string; groups: string }>(
        `SELECT (SELECT count(*) FROM canonical_products) AS products,
                (SELECT count(*) FROM product_groups) AS groups`,
      );
      res.json({
        ok: true,
        latencyMs: Date.now() - started,
        commit: env.commit,
        catalog: { products: Number(k!.products), groups: Number(k!.groups) },
      });
    } catch (err) {
      res.status(503).json({
        ok: false,
        commit: env.commit,
        error: err instanceof Error ? err.message : 'Veritabanına ulaşılamadı',
      });
    }
  });

  app.use('/auth', authRouter);
  app.use('/account', accountRouter);
  app.use('/official', officialRouter);
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
