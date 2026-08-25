/**
 * Eşleştirme ölçümü ve eşik taraması.
 *
 * Eşik değerleri göz kararı ayarlanmıştı ve genellemedi. Bu betik onları
 * ölçüyle seçtiriyor: etiketli küme (test/fixtures/match-eval.ts) üzerinde
 * eşiği ve marjı tarayıp her kombinasyonda üç sayıyı raporluyor.
 *
 *   YANLIŞ  otomatik bağlandı ama ürün yanlış. Sıfır olmak ZORUNDA —
 *           endeks birim fiyattan hesaplandığı için sessizce yanlış
 *           enflasyon üretiyor. Kullanıcıya soran bir sistem yavaştır;
 *           yanlış bağlayan bir sistem bozuktur.
 *   DOĞRU   otomatik bağlandı ve doğru.
 *   SORULDU kullanıcıya soruldu. Her zaman hata değil: fişte boy
 *           yazmıyorsa sormak doğru davranış.
 *
 * Kullanım:
 *   npx tsx scripts/match-eval.ts           mevcut ayarlarla rapor
 *   npx tsx scripts/match-eval.ts --sweep   eşik/marj taraması
 */
import { pool, query } from '../src/db.js';
import { decide, matchCatalog, type Candidate } from '../src/catalog-match.js';
import {
  MATCH_CASES,
  NEGATIVE_CASES,
  type MatchCase,
} from '../test/fixtures/match-eval.js';

type Sonuc = {
  vaka: MatchCase;
  auto: Candidate | null;
  dogruMu: boolean;
  sizeAmbiguous: boolean;
  best: Candidate | null;
};

/** Adayın etiketle aynı kalem olup olmadığı — üçlü kimlikten. */
function esitMi(c: Candidate, v: MatchCase): boolean {
  return (
    c.groupName === v.group &&
    (c.brandName ?? null) === v.brand &&
    c.sizeLabel === v.size
  );
}

async function calistir(): Promise<Sonuc[]> {
  const out: Sonuc[] = [];
  for (const vaka of MATCH_CASES) {
    const o = await matchCatalog(vaka.raw, 6);
    out.push({
      vaka,
      auto: o.auto,
      dogruMu: o.auto ? esitMi(o.auto, vaka) : false,
      sizeAmbiguous: o.sizeAmbiguous,
      best: o.best,
    });
  }
  return out;
}

function ozet(sonuclar: Sonuc[]) {
  const dogru = sonuclar.filter((s) => s.auto && s.dogruMu).length;
  const yanlis = sonuclar.filter((s) => s.auto && !s.dogruMu).length;
  const soruldu = sonuclar.filter((s) => !s.auto).length;
  return { dogru, yanlis, soruldu, toplam: sonuclar.length };
}

/**
 * Olumsuz vakalar: otomatik bağlanan her biri hata.
 *
 * Bağlanmasa bile karar adayının puanı önemli — eşiğin o puanların ne
 * kadar üstünde durduğu, kümenin dışındaki verideki emniyet payı.
 */
async function olumsuz() {
  const satir: { raw: string; best: string; puan: number; bagli: boolean }[] = [];
  for (const raw of NEGATIVE_CASES) {
    const o = await matchCatalog(raw, 6);
    satir.push({
      raw,
      best: o.best?.displayName ?? '(aday yok)',
      puan: o.best?.score ?? 0,
      bagli: o.auto !== null,
    });
  }
  return satir.sort((a, b) => b.puan - a.puan);
}

async function rapor() {
  const sonuclar = await calistir();
  const s = ozet(sonuclar);
  const yuzde = (n: number) => `%${((100 * n) / s.toplam).toFixed(1)}`;

  console.log(`\nEtiketli vaka: ${s.toplam}`);
  console.log(`  DOĞRU otomatik : ${s.dogru}  ${yuzde(s.dogru)}`);
  console.log(`  YANLIŞ otomatik: ${s.yanlis}  ${yuzde(s.yanlis)}`);
  console.log(`  SORULDU        : ${s.soruldu}  ${yuzde(s.soruldu)}`);

  const yanlislar = sonuclar.filter((x) => x.auto && !x.dogruMu);
  if (yanlislar.length) {
    console.log('\n--- YANLIŞ BAĞLANANLAR (sıfır olmalı) ---');
    for (const x of yanlislar) {
      console.log(`  ${x.vaka.raw}`);
      console.log(
        `    bağlandı: ${x.auto!.displayName}  (${x.auto!.score.toFixed(3)})`,
      );
      console.log(`    olmalıydı: ${x.vaka.brand ?? '(markasız)'} ${x.vaka.group} ${x.vaka.size}`);
    }
  }

  const sorulanlar = sonuclar.filter((x) => !x.auto);
  if (sorulanlar.length) {
    console.log('\n--- SORULANLAR ---');
    for (const x of sorulanlar) {
      // Boy fişte yazmıyorsa sormak doğru; ayırt edilebilsin diye
      // sebebi yazılıyor.
      const sebep = x.sizeAmbiguous ? 'boy fişte yok' : 'puan yetersiz';
      const ilk = x.best
        ? `${x.best.displayName} ${x.best.score.toFixed(3)}`
        : 'aday yok';
      // Karar adayı: boy süzgecinden geçmiş havuzun ilki.
      const isabet = x.best && esitMi(x.best, x.vaka) ? '✓' : '✗';
      console.log(`  [${sebep}] ${x.vaka.raw}`);
      console.log(`      karar adayı ${isabet} ${ilk}`);
    }
  }

  const neg = await olumsuz();
  const hata = neg.filter((n) => n.bagli).length;
  console.log(
    `\nOlumsuz vaka: ${neg.length}  — yanlış bağlanan: ${hata}`,
  );
  console.log('  (puana göre; eşiğin emniyet payı en üstteki satırla ölçülür)');
  for (const n of neg.slice(0, 6)) {
    console.log(
      `  ${n.bagli ? '✗ BAĞLANDI' : '  ok      '} ${n.puan.toFixed(3)}  ` +
        `${n.raw}  →  ${n.best}`,
    );
  }

  await pool.end();
}

/**
 * Eşik ve marj taraması.
 *
 * Adaylar bir kez çekiliyor, karar aynı [decide] fonksiyonuyla farklı
 * ayarlarla yeniden veriliyor — ölçülen şey ile üretimde çalışan şey
 * aynı kod.
 */
async function tara() {
  const ham: { vaka: MatchCase; adaylar: Candidate[] }[] = [];
  for (const vaka of MATCH_CASES) {
    const o = await matchCatalog(vaka.raw, 6);
    ham.push({ vaka, adaylar: o.candidates });
  }
  const negHam: { raw: string; adaylar: Candidate[] }[] = [];
  for (const raw of NEGATIVE_CASES) {
    const o = await matchCatalog(raw, 6);
    negHam.push({ raw, adaylar: o.candidates });
  }

  console.log('\n eşik  marj | DOĞRU YANLIŞ SORULDU | OLUMSUZ-HATA');
  console.log('------------+----------------------+-------------');
  for (const threshold of [0.5, 0.6, 0.62, 0.65, 0.68, 0.7, 0.75, 0.85]) {
    for (const margin of [0, 0.005, 0.01, 0.02, 0.05]) {
      let dogru = 0, yanlis = 0, soruldu = 0;
      for (const h of ham) {
        const k = decide(h.vaka.raw, h.adaylar, { threshold, margin });
        if (!k.auto) soruldu++;
        else if (esitMi(k.auto, h.vaka)) dogru++;
        else yanlis++;
      }
      let negHata = 0;
      for (const n of negHam) {
        if (decide(n.raw, n.adaylar, { threshold, margin }).auto) negHata++;
      }
      const bayrak = yanlis + negHata > 0 ? '  ←' : '';
      console.log(
        ` ${threshold.toFixed(2)}  ${margin.toFixed(3)} |` +
          ` ${String(dogru).padStart(5)} ${String(yanlis).padStart(6)}` +
          ` ${String(soruldu).padStart(8)} |` +
          ` ${String(negHata).padStart(12)}${bayrak}`,
      );
    }
  }
  await pool.end();
}

const kayitli = await query<{ n: string }>(
  `SELECT count(*)::text AS n FROM canonical_products`,
);
console.log(`katalog: ${kayitli[0]!.n} kanonik ürün`);

if (process.argv.includes('--sweep')) await tara();
else await rapor();
