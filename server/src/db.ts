import pg from 'pg';

// numeric (NUMERIC/DECIMAL) varsayılan olarak string döner — endeks
// karşılaştırmalarında sayı istiyoruz. Parasal alanlarda kayan nokta riski
// var ama testlerde ve API cevabında sayı olması daha kullanışlı; kritik
// toplama işlemleri zaten veritabanında yapılıyor.
pg.types.setTypeParser(pg.types.builtins.NUMERIC, (v) => Number(v));

export const pool = new pg.Pool({
  connectionString:
    process.env.DATABASE_URL ?? 'postgres://localhost:5432/sepet',
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
