/**
 * Ortam değişkenleri tek yerde okunur ve doğrulanır — eksik bir sır, çalışma
 * anında değil açılışta patlasın.
 */
const dev = (process.env.NODE_ENV ?? 'development') !== 'production';

export const env = {
  isDev: dev,
  // 3000 sıklıkla dolu oluyor; Sepet 4000'de.
  port: Number(process.env.PORT ?? 4000),
  databaseUrl:
    process.env.DATABASE_URL ?? 'postgres://localhost:5432/sepet',
  jwtSecret: process.env.JWT_SECRET ?? (dev ? 'dev-secret-degistir' : ''),
  /** Sağlayıcısız geliştirme girişi. Üretimde asla açık olmamalı. */
  devLoginEnabled:
    (process.env.DEV_LOGIN ?? (dev ? 'true' : 'false')) === 'true',
};

if (!env.jwtSecret) {
  throw new Error('JWT_SECRET tanımlı değil');
}
if (!env.isDev && env.devLoginEnabled) {
  throw new Error('DEV_LOGIN üretimde açık olamaz');
}
