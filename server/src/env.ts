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
  /** Sağlayıcısız giriş. Geliştirmede herkese, üretimde yalnızca listedekilere. */
  devLoginEnabled:
    (process.env.DEV_LOGIN ?? (dev ? 'true' : 'false')) === 'true',

  /**
   * Üretimde sağlayıcısız girişe izin verilen adresler.
   *
   * Gerçek Apple/Google akışı gelene kadar dağıtılmış sunucuya girmenin tek
   * yolu bu uç. Üretimde herkese açık bırakmak isteyen herkese hesap açmak
   * demek olurdu; liste boşsa uç kapalı.
   */
  devLoginAllowlist: (process.env.DEV_LOGIN_EMAILS ?? '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean),
};

if (!env.jwtSecret) {
  throw new Error('JWT_SECRET tanımlı değil');
}
if (!env.isDev && env.devLoginEnabled && env.devLoginAllowlist.length === 0) {
  throw new Error(
    'Üretimde DEV_LOGIN açıksa DEV_LOGIN_EMAILS ile kimlerin girebileceği ' +
      'belirtilmeli — aksi hâlde uç herkese açık olur',
  );
}
