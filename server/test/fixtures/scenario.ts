import { one, query } from '../../src/db.js';

/** Testlerin kurduğu senaryo için gereken kimlikler. */
export interface Scenario {
  userId: string;
  merchantId: string;
  /** Ürün adı -> kanonik ürün kimliği */
  products: Record<string, string>;
  /** Ay ofsetini (0 = bu ay, -1 = geçen ay) tarihe çevirir. */
  month(offset: number): string;
}

/**
 * Testler takvime göre kaymasın diye tüm tarihler **bugünün ayına göreli**
 * kuruluyor. Sabit tarih yazılsaydı zaman geçtikçe boşluk doldurma devreye
 * girer ve beklenen değerler kayardı.
 */
export async function startScenario(name: string): Promise<Scenario> {
  // pg, DATE sütununu JS Date'ine çeviriyor; metin olarak istiyoruz.
  const { month0 } = await one<{ month0: string }>(
    `SELECT to_char(date_trunc('month', current_date), 'YYYY-MM-DD') AS month0`,
  );

  const user = await one<{ id: string }>(
    `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
    [`${name}-${Date.now()}@sepet.test`, name],
  );

  const merchant = await one<{ id: string }>(
    `INSERT INTO merchants (name, chain_code) VALUES ($1, $2) RETURNING id`,
    [`Market ${name}`, `${name}-${Date.now()}`],
  );

  return {
    userId: user.id,
    merchantId: merchant.id,
    products: {},
    month(offset: number) {
      const d = new Date(`${month0}T00:00:00Z`);
      d.setUTCMonth(d.getUTCMonth() + offset);
      return d.toISOString().slice(0, 10);
    },
  };
}

let categoryId: string | null = null;

async function ensureCategory(): Promise<string> {
  if (categoryId) return categoryId;
  const rows = await query<{ id: string }>(
    `SELECT id FROM categories WHERE code = 'TEST'`,
  );
  categoryId =
    rows[0]?.id ??
    (
      await one<{ id: string }>(
        `INSERT INTO categories (code, name) VALUES ('TEST', 'Test') RETURNING id`,
      )
    ).id;
  return categoryId;
}

/** Kanonik ürün ekler. [sizeValue] kanonik birim cinsinden paket içeriği. */
export async function addProduct(
  s: Scenario,
  key: string,
  opts: { name: string; sizeLabel: string; unit: string; sizeValue: number },
): Promise<string> {
  const cat = await ensureCategory();
  const p = await one<{ id: string }>(
    `INSERT INTO canonical_products (name, size_label, unit, size_value, category_id)
     VALUES ($1, $2, $3::product_unit, $4, $5) RETURNING id`,
    [
      `${opts.name} ${s.userId.slice(0, 8)}`,
      opts.sizeLabel,
      opts.unit,
      opts.sizeValue,
      cat,
    ],
  );
  s.products[key] = p.id;
  return p.id;
}

export interface LineSpec {
  product: string;
  quantity?: number;
  amount: number;
  raw?: string;
  status?: 'pending' | 'auto' | 'confirmed' | 'rejected';
}

/** Belirtilen aya bir fiş yazar. [day] ayın kaçıncı günü. */
export async function addReceipt(
  s: Scenario,
  monthOffset: number,
  lines: LineSpec[],
  day = 14,
): Promise<string> {
  const month = s.month(monthOffset);
  const date = `${month.slice(0, 8)}${String(day).padStart(2, '0')}`;
  const total = lines.reduce((a, l) => a + l.amount, 0);

  const receipt = await one<{ id: string }>(
    `INSERT INTO receipts (user_id, merchant_id, purchased_at, total_amount)
     VALUES ($1, $2, $3, $4) RETURNING id`,
    [s.userId, s.merchantId, date, total],
  );

  for (const [i, l] of lines.entries()) {
    await query(
      `INSERT INTO receipt_lines
         (receipt_id, line_no, raw_text, quantity, line_amount,
          canonical_product_id, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7::match_status)`,
      [
        receipt.id,
        i + 1,
        l.raw ?? l.product.toUpperCase(),
        l.quantity ?? 1,
        l.amount,
        s.products[l.product],
        l.status ?? 'confirmed',
      ],
    );
  }
  return receipt.id;
}

export async function refresh(s: Scenario): Promise<void> {
  await query(`SELECT refresh_user_index($1)`, [s.userId]);
}

export async function cleanup(s: Scenario): Promise<void> {
  await query(`DELETE FROM users WHERE id = $1`, [s.userId]);
  await query(`DELETE FROM merchants WHERE id = $1`, [s.merchantId]);
}
