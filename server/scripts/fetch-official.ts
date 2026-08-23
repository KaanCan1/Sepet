/**
 * TÜİK TÜFE'yi EVDS'ten çeker.  npm run official
 *
 * Elle ya da bir zamanlayıcıdan çalıştırmak için. Sunucu da açılışta
 * kendisi deniyor; bu betik onu beklemeden tetiklemek isteyene.
 */
import { pool } from '../src/db.js';
import { refreshOfficial } from '../src/official/refresh.js';

const result = await refreshOfficial({ force: true });

if (result.skipped === 'no-key') {
  console.error('EVDS_API_KEY tanımlı değil.');
  await pool.end();
  process.exit(1);
}

console.log(`  yazılan ay   ${result.written}`);
console.log(`  en yeni ay   ${result.newestMonth ?? '—'}`);
await pool.end();
