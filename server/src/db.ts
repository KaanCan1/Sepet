import pg from 'pg';

// numeric (NUMERIC/DECIMAL) varsayılan olarak string döner — endeks
// karşılaştırmalarında sayı istiyoruz. Parasal alanlarda kayan nokta riski
// var ama testlerde ve API cevabında sayı olması daha kullanışlı; kritik
// toplama işlemleri zaten veritabanında yapılıyor.
pg.types.setTypeParser(pg.types.builtins.NUMERIC, (v) => Number(v));

// DATE olduğu gibi, dizge olarak dönüyor — Date nesnesine çevrilmiyor.
//
// Varsayılan çözümleyici "2026-08-24" gününü yerel gece yarısına bağlı bir
// Date yapıyor; JSON'a yazılırken de UTC'ye çevriliyor ve tel üzerinde
// "2026-08-23T21:00:00.000Z" görünüyor. İstemci bunu ayrıştırdığında elinde
// UTC bir tarih oluyor ve gün alanını okuyunca 24 değil 23 çıkıyor: fişler
// bir gün geriden görünüyordu.
//
// Tek tek sorgulara to_char eklemek işe yarıyordu ama her yeni sorguda
// hatırlanması gereken bir şey bırakıyordu — ve unutulduğunda hata sessiz.
// Kaynağı kapatmak daha güvenli: bu sütunların saat bileşeni zaten yok,
// dolayısıyla saat dilimi de yok.
pg.types.setTypeParser(pg.types.builtins.DATE, (v) => v);

const connectionString =
  process.env.DATABASE_URL ?? 'postgres://localhost:5432/sepet';

/// Neon gibi barındırılan Postgres'ler TLS istiyor; yerel geliştirmede yok.
///
/// Sunucu adını elle aramak yerine adresi ayrıştırıyoruz: yerel bağlantı
/// dizesinde kullanıcı adı olmadığı için "@localhost" araması tutmuyordu.
function requiresSsl(url: string): boolean {
  try {
    const parsed = new URL(url);
    if (parsed.searchParams.get('sslmode') === 'disable') return false;
    const local = ['localhost', '127.0.0.1', '::1', ''];
    return !local.includes(parsed.hostname);
  } catch {
    return false;
  }
}

const needsSsl = requiresSsl(connectionString);

export const pool = new pg.Pool({
  connectionString,
  // Neon zinciri Node'un kök deposunda olmayabiliyor; şifreleme yine geçerli,
  // yalnızca zincir doğrulaması gevşetiliyor.
  ssl: needsSsl ? { rejectUnauthorized: false } : undefined,
  max: Number(process.env.PG_POOL_MAX ?? 10),
  // Neon askıdan uyanırken ilk bağlantı saniyeler sürebiliyor; varsayılan
  // süre dolup istek düşüyordu.
  connectionTimeoutMillis: Number(process.env.PG_CONNECT_TIMEOUT_MS ?? 15000),
  idleTimeoutMillis: 30000,
});

export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  sql: string,
  params: unknown[] = [],
): Promise<T[]> {
  const res = await pool.query<T>(sql, params);
  return res.rows;
}

export async function one<T extends pg.QueryResultRow = pg.QueryResultRow>(
  sql: string,
  params: unknown[] = [],
): Promise<T> {
  const rows = await query<T>(sql, params);
  if (rows.length !== 1) {
    throw new Error(`Tek satır bekleniyordu, ${rows.length} geldi`);
  }
  return rows[0]!;
}
