/**
 * Ortam değişkenleri tek yerde okunur ve doğrulanır — eksik bir sır, çalışma
 * anında değil açılışta patlasın.
 */
const dev = (process.env.NODE_ENV ?? 'development') !== 'production';

/**
 * Çalışan sürümün commit'i.
 *
 * Render bunu her dağıtımda kendi veriyor (RENDER_GIT_COMMIT). Yereldeyse
 * yok ve olmaması normal — o yüzden eksikliği açılışta patlatılmıyor.
 *
 * Buna ihtiyaç ölçerek doğdu: "yeni kod canlıda mı?" sorusunu dışarıdan
 * cevaplamanın hiçbir yolu yoktu. Uçların 401 dönmesi kanıt sanılmıştı,
 * oysa requireAuth bütün router'a bağlı ve YOLU OLMAYAN bir istek de 401
 * dönüyor. Dağıtımın geçip geçmediği tahminle konuşuluyordu.
 */
function commitOku(): string | null {
  const ham = process.env.RENDER_GIT_COMMIT ?? process.env.GIT_COMMIT ?? '';
  const temiz = ham.trim();
  // Kısa hâli yeterli ve göze okunur; tam SHA'yı arayan zaten depoya bakar.
  return temiz ? temiz.slice(0, 7) : null;
}

export const env = {
  isDev: dev,
  commit: commitOku(),
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

/// Eksik yapılandırmayı tek seferde bildirir.
///
/// Önceden ilk eksikte patlıyordu; Render'da bir değişkeni düzeltip yeniden
/// dağıtınca bu sefer diğeri patlıyordu. Hepsini birden söylemek tur sayısını
/// düşürüyor.
const problems: string[] = [];

if (!env.jwtSecret) {
  problems.push('JWT_SECRET tanımlı değil.');
}

if (!process.env.DATABASE_URL) {
  problems.push(
    'DATABASE_URL tanımlı değil. Neon bağlantı dizesini Render panelinde ' +
      'Environment altına gir (sslmode=require ile birlikte).',
  );
}

if (!env.isDev && env.devLoginEnabled && env.devLoginAllowlist.length === 0) {
  problems.push(
    'DEV_LOGIN açık ama DEV_LOGIN_EMAILS boş. Gerçek Apple/Google akışı ' +
      'gelene kadar girişin tek yolu bu uç; kimlerin girebileceği ' +
      'belirtilmezse uç herkese açık olurdu. Kendi e-postanı gir.',
  );
}

if (problems.length > 0) {
  throw new Error(
    `Sunucu başlatılamadı — eksik yapılandırma:\n` +
      problems.map((p) => `  • ${p}`).join('\n'),
  );
}
