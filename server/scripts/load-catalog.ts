/**
 * Referans kataloğu yükler.
 *
 * `psql` üzerinden çalıştırmak yerine Node'dan: Render'ın Node ortamında
 * Postgres istemcisi kurulu değil ve tek bir bağımlılık için kurmak gereksiz.
 */
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/db.js';

const here = dirname(fileURLToPath(import.meta.url));

async function main(): Promise<void> {
  const sql = await readFile(join(here, '..', 'seeds', 'catalog.sql'), 'utf8');
  await pool.query(sql);

  const { rows } = await pool.query<{ products: string; merchants: string }>(
    `SELECT (SELECT count(*) FROM canonical_products) AS products,
            (SELECT count(*) FROM merchants) AS merchants`,
  );
  console.log(
    `Katalog hazır: ${rows[0]!.products} ürün, ${rows[0]!.merchants} market`,
  );
  await pool.end();
}

main().catch(async (err) => {
  console.error(err);
  await pool.end();
  process.exit(1);
});
