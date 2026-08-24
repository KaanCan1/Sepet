import { query } from '../../src/db.js';

/**
 * Referans katalogdan tek bir kanonik ürün seçer.
 *
 * Kanonik ürünün kimliği ÜÇ alandan oluşuyor — grup, marka, boy — ve
 * tekil indeks de tam bu üçlü üzerinde (013_custom_size).
 *
 * Testler bu kimliğin bir kısmını yazıp "nasılsa tek satır gelir" varsayıyordu.
 * Katalog her büyüdüğünde varsayımlardan biri kırıldı: önce yumurta (Migros'un
 * 30'lusu eklenince), sonra süt, sonra zeytinyağı. Kırılan şey testin konusu
 * değildi — sorgunun eksikliğiydi.
 *
 * Üç alanı da zorunlu tutmak varsayımı ortadan kaldırıyor: sonuç ya tektir ya
 * da hata. Bulunamazsa hata mesajı o grupta gerçekte hangi boyların olduğunu
 * yazıyor, çünkü bu testi düzelten kişinin ihtiyacı olan bilgi tam olarak o.
 *
 * @param brandName Markasız kalemler (kasada tartılanlar) için null.
 */
export async function canonicalId(
  groupName: string,
  brandName: string | null,
  sizeLabel: string,
): Promise<string> {
  const rows = await query<{ id: string }>(
    `SELECT id FROM v_canonical_products
      WHERE group_name = $1
        AND brand_name IS NOT DISTINCT FROM $2
        AND size_label = $3`,
    [groupName, brandName, sizeLabel],
  );

  if (rows.length === 1) return rows[0]!.id;

  const mevcut = await query<{ brand_name: string | null; size_label: string }>(
    `SELECT brand_name, size_label FROM v_canonical_products
      WHERE group_name = $1 ORDER BY brand_name NULLS FIRST, size_value`,
    [groupName],
  );
  const liste = mevcut.length
    ? mevcut.map((r) => `${r.brand_name ?? '(markasız)'} ${r.size_label}`).join(', ')
    : 'grupta hiç ürün yok';

  throw new Error(
    `Katalogda tek kalem bekleniyordu: ${groupName} / ` +
      `${brandName ?? '(markasız)'} / ${sizeLabel} — ${rows.length} geldi.\n` +
      `Gruptaki kalemler: ${liste}`,
  );
}
