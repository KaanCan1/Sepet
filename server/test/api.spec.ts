import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { one, pool, query } from '../src/db.js';
import { canonicalId } from './fixtures/catalog-ref.js';

const app = createApp();

let token = '';
let userId = '';
let merchantId = '';
let sutId = '';
let yumurtaId = '';
/** Alias tablosu koşular arası kalıcı; her koşu kendi ham metnini kullansın. */
const uniqueRaw = `ZEYTIN YAGI SIZMA ${Date.now()}`;

beforeAll(async () => {
  const email = `api-${Date.now()}@sepet.test`;
  const res = await request(app).post('/auth/dev-login').send({ email });
  token = res.body.token;
  userId = res.body.userId;

  merchantId = (
    await one<{ id: string }>(
      `SELECT id FROM merchants WHERE chain_code = 'BIM'`,
    )
  ).id;
  sutId = await canonicalId('Süt, tam yağlı', 'Sütaş', '1 litre');
  yumurtaId = await canonicalId('Yumurta', null, "30'lu");
});

afterAll(async () => {
  if (userId) await query(`DELETE FROM users WHERE id = $1`, [userId]);
  // Test kendi alias izini bırakmasın.
  await query(
    `DELETE FROM product_aliases WHERE raw_text_normalized = normalize_raw_text($1)`,
    [uniqueRaw],
  );
  await pool.end();
});

const auth = () => ({ Authorization: `Bearer ${token}` });

/** Belirtilen ay ofsetinde bir tarih üretir. */
function monthsAgo(n: number, day = 14): string {
  const d = new Date();
  d.setDate(1);
  d.setMonth(d.getMonth() - n);
  d.setDate(day);
  return d.toISOString().slice(0, 10);
}

describe('API', () => {
  it('canlılık ucu veritabanına dokunmuyor', async () => {
    // Render dağıtım kararını buna bakarak veriyor; Neon askıdayken bile
    // 200 dönmeli, yoksa soğuk başlatma dağıtımı öldürür.
    await request(app).get('/health').expect(200, { ok: true });
  });

  it('hazırlık ucu veritabanını gerçekten yokluyor', async () => {
    const res = await request(app).get('/health/db').expect(200);
    expect(res.body.ok).toBe(true);
    expect(typeof res.body.latencyMs).toBe('number');
  });

  it('oturumsuz istek 401 döner', async () => {
    await request(app).get('/index').expect(401);
    await request(app).get('/receipts').expect(401);
  });

  it('geçersiz token 401 döner', async () => {
    await request(app)
      .get('/index')
      .set({ Authorization: 'Bearer uydurma.token.degeri' })
      .expect(401);
  });

  it('boş hesapta endeks null döner, hata değil', async () => {
    const res = await request(app).get('/index').set(auth()).expect(200);
    expect(res.body.headline).toBeNull();
    expect(res.body.series).toEqual([]);
  });

  it('fiş kaydedilir ve endeks anında güncellenir', async () => {
    const first = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(2),
        lines: [
          { raw: 'SUT TAM YAGLI 1L', quantity: 2, amount: 80, canonicalProductId: sutId },
          { raw: 'YUMURTA 30LU', amount: 120, canonicalProductId: yumurtaId },
        ],
      })
      .expect(201);
    expect(first.body.id).toBeTruthy();

    await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(1),
        lines: [
          { raw: 'SUT TAM YAGLI 1L', quantity: 2, amount: 100, canonicalProductId: sutId },
          { raw: 'YUMURTA 30LU', amount: 132, canonicalProductId: yumurtaId },
        ],
      })
      .expect(201);

    const res = await request(app).get('/index').set(auth()).expect(200);
    // Altın senaryodaki ilk halka: %16.
    expect(res.body.headline.changePct).toBeCloseTo(16, 5);
    // Bu ay alışveriş yok; fiyatlar taşınıyor ve seri bu aya kadar uzuyor.
    // Taşınan ayın halkası 1,0 olduğu için seviye 116'da kalıyor.
    expect(res.body.headline.windowMonths).toBe(2);
    expect(res.body.series).toHaveLength(3);
    expect(res.body.series.at(-1).momPct).toBeCloseTo(0, 5);
    // Resmî seriler katalogdan geliyor.
    expect(res.body.official.map((o: { code: string }) => o.code)).toContain(
      'TUIK_TUFE',
    );
  });

  it('eksik alanla fiş reddedilir', async () => {
    await request(app)
      .post('/receipts')
      .set(auth())
      .send({ merchantId })
      .expect(400);
  });

  it('bilinmeyen satır pending kalır, onaylanınca alias yazılır', async () => {
    const created = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(0),
        lines: [{ raw: uniqueRaw, amount: 340 }],
      })
      .expect(201);

    const detail = await request(app)
      .get(`/receipts/${created.body.id}`)
      .set(auth())
      .expect(200);
    expect(detail.body.lines[0].status).toBe('pending');
    expect(detail.body.lines[0].canonical).toBeNull();

    const zeytinId = await canonicalId('Zeytinyağı', 'Komili', '1 litre');
    await request(app)
      .post(`/receipts/${created.body.id}/lines/${detail.body.lines[0].id}/match`)
      .set(auth())
      .send({ canonicalProductId: zeytinId })
      .expect(200);

    // Aynı market + aynı ham metin bir daha sorulmamalı.
    const again = await request(app)
      .post('/receipts')
      .set(auth())
      .send({
        merchantId,
        purchasedAt: monthsAgo(0, 25),
        // Küçük harf ve fazladan boşluk: normalize_raw_text ikisini eşitliyor.
        lines: [{ raw: uniqueRaw.toLowerCase().replace(' ', '  '), amount: 355 }],
      })
      .expect(201);

    const secondDetail = await request(app)
      .get(`/receipts/${again.body.id}`)
      .set(auth())
      .expect(200);
    expect(secondDetail.body.lines[0].status).toBe('auto');
    expect(secondDetail.body.lines[0].canonical).toContain('Zeytinyağı');
  });

  it('ürün listesi ve geçmişi döner', async () => {
    const list = await request(app).get('/products').set(auth()).expect(200);
    const sut = list.body.find((p: { id: string }) => p.id === sutId);
    expect(sut).toBeTruthy();
    // 40 -> 50 TL/L
    expect(sut.changePct).toBeCloseTo(25, 5);

    const detail = await request(app)
      .get(`/products/${sutId}`)
      .set(auth())
      .expect(200);
    expect(detail.body.history).toHaveLength(2);
    expect(detail.body.byMerchant[0].merchant).toBe('BİM');
  });

  it('bilinmeyen ürün 404', async () => {
    await request(app)
      .get('/products/00000000-0000-0000-0000-000000000000')
      .set(auth())
      .expect(404);
  });

  it('katalog araması Türkçe karakterden bağımsız', async () => {
    const res = await request(app)
      .get('/products/catalog/search?q=aycicek')
      .set(auth())
      .expect(200);
    // Görünen ad marka + grup + boy: "Yudum Ayçiçek yağı 5 litre".
    expect(
      res.body.some((p: { groupName: string }) => p.groupName === 'Ayçiçek yağı'),
    ).toBe(true);
  });

  // Fişte "TACIROGLU SUT" yazan kalem aslında kaşar peyniri olabiliyor.
  // Kullanıcı gram girdiğinde yanlış olan birim değil grup: 400 g'ı litre
  // cinsinden bir grupta saklamak endeksin birimini bozar. Bu uç nokta
  // doğru grubu seçtiriyor.
  it('grup listesi ölçü birimine göre süzülüyor', async () => {
    const res = await request(app)
      .get('/products/catalog/groups?unit=kilogram&q=peynir')
      .set(auth())
      .expect(200);

    const adlar = res.body.map((g: { name: string }) => g.name);
    expect(adlar).toContain('Kaşar peyniri');
    // Süzgeç birimi tutuyor: litre grubu bu listede olamaz.
    expect(
      res.body.every((g: { unit: string }) => g.unit === 'kilogram'),
    ).toBe(true);
  });

  it('grup araması Türkçe karakterden bağımsız', async () => {
    const res = await request(app)
      .get('/products/catalog/groups?q=kasar')
      .set(auth())
      .expect(200);
    expect(
      res.body.some((g: { name: string }) => g.name === 'Kaşar peyniri'),
    ).toBe(true);
  });

  // Endeks iki FARKLI ayda fiş istiyor; sepet karşılaştırması istemiyor.
  // Kullanıcının eline endeksten önce geçen tek somut şey bu.
  describe('Sepet karşılaştırması', () => {
    // Kendi kullanıcısı: dosyadaki diğer testler tek markette alışveriş
    // ediyor ve karşılaştırma tam olarak İKİ market gerektiriyor.
    let kToken = '';
    let kUserId = '';

    const kAuth = () => ({ Authorization: `Bearer ${kToken}` });

    beforeAll(async () => {
      const res = await request(app)
        .post('/auth/dev-login')
        .send({ email: `sepet-${Date.now()}@sepet.test` });
      kToken = res.body.token;
      kUserId = res.body.userId;

      const ucuz = (
        await one<{ id: string }>(
          `SELECT id FROM merchants WHERE chain_code = 'A101'`,
        )
      ).id;

      // Aynı ürün, iki market: A101'de 50, BİM'de 60. Endeks için iki ay
      // gerekiyordu; buradaki soru "hangi market" olduğu için aynı ay da
      // yetiyor — zaten fark ettirmek istediğimiz şey de bu.
      await request(app)
        .post('/receipts')
        .set(kAuth())
        .send({
          merchantId: ucuz,
          purchasedAt: monthsAgo(1),
          lines: [{ raw: 'SUT TAM YAGLI 1L', amount: 50, canonicalProductId: sutId }],
        })
        .expect(201);

      await request(app)
        .post('/receipts')
        .set(kAuth())
        .send({
          merchantId,
          purchasedAt: monthsAgo(0),
          lines: [{ raw: 'SUT TAM YAGLI 1L', amount: 60, canonicalProductId: sutId }],
        })
        .expect(201);
    });

    afterAll(async () => {
      if (kUserId) await query(`DELETE FROM users WHERE id = $1`, [kUserId]);
    });

    it('daha ucuz gördüğü alternatifi adıyla söylüyor', async () => {
      const res = await request(app)
        .get('/index/basket')
        .set(kAuth())
        .expect(200);

      expect(res.body.comparable).toBe(true);
      expect(res.body.merchant).toBe('BİM');
      expect(res.body.items).toHaveLength(1);

      const [kalem] = res.body.items;
      expect(kalem.paid).toBeCloseTo(60, 2);
      expect(kalem.bestPaid).toBeCloseTo(50, 2);
      expect(kalem.saved).toBeCloseTo(10, 2);
      expect(res.body.saved).toBeCloseTo(10, 2);

      // Kullanıcı neyle kıyaslandığını görmeden sayıya inanmak zorunda
      // kalmasın: alternatifin adı, marketi ve tarihi geliyor.
      expect(kalem.bestMerchant).toBe('A101');
      expect(kalem.bestName).toContain('Süt');
      expect(kalem.bestSeenOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });

    it('aynı üründe zaman farkı tasarruf sayılmıyor', async () => {
      // Aynı markette daha ucuza görmüş olmak bir seçim değil; onu tasarruf
      // diye yazmak enflasyonu indirim gibi göstermek olurdu. Bu dosyadaki
      // ana kullanıcı tek markette alışveriş ediyor ve fiyatları artmış.
      const res = await request(app).get('/index/basket').set(auth()).expect(200);
      expect(res.body.comparable).toBe(false);
    });

    it('kıyaslanacak veri yoksa comparable false', async () => {
      const bos = await request(app)
        .post('/auth/dev-login')
        .send({ email: `bos-${Date.now()}@sepet.test` })
        .expect(200);

      const res = await request(app)
        .get('/index/basket')
        .set('Authorization', `Bearer ${bos.body.token}`)
        .expect(200);

      // "Tasarruf yok" ile "kıyaslayacak şey yok" ayrı: ekran ikincisinde
      // 0 TL yazmamalı.
      expect(res.body.comparable).toBe(false);
      expect(res.body.saved).toBeUndefined();

      await query(`DELETE FROM users WHERE id = $1`, [bos.body.userId]);
    });
  });

  // Fiş tarihleri bir gün geriden görünüyordu: pg bir DATE sütununu yerel
  // gece yarısına bağlı bir Date yapıyor, JSON'a giderken de UTC'ye
  // çeviriyordu. "2026-08-24" tel üzerinde "2026-08-23T21:00:00.000Z"
  // oluyor ve istemci gün alanını okuyunca 23 çıkıyordu.
  describe('Tarihler saat diliminden kaymıyor', () => {
    const gun = '2026-03-14';
    let fisId = '';

    beforeAll(async () => {
      const res = await request(app)
        .post('/receipts')
        .set(auth())
        .send({
          merchantId,
          purchasedAt: gun,
          lines: [{ raw: 'YUMURTA 30LU', amount: 150, canonicalProductId: yumurtaId }],
        })
        .expect(201);
      fisId = res.body.id;
    });

    afterAll(async () => {
      if (fisId) await query(`DELETE FROM receipts WHERE id = $1`, [fisId]);
    });

    it('fiş listesi yazılan günü döndürüyor', async () => {
      const res = await request(app).get('/receipts').set(auth()).expect(200);
      const fis = res.body.find((r: { id: string }) => r.id === fisId);
      // Saat bileşeni hiç olmamalı: olduğu anda saat dilimi devreye giriyor.
      expect(fis.purchasedAt).toBe(gun);
    });

    it('fiş detayı yazılan günü döndürüyor', async () => {
      const res = await request(app)
        .get(`/receipts/${fisId}`)
        .set(auth())
        .expect(200);
      expect(res.body.purchasedAt).toBe(gun);
    });

    it('ürün geçmişindeki gözlem günü kaymıyor', async () => {
      const res = await request(app)
        .get(`/products/${yumurtaId}`)
        .set(auth())
        .expect(200);
      for (const nokta of res.body.history) {
        expect(nokta.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      }
      expect(res.body.history.some((h: { date: string }) => h.date === gun)).toBe(
        true,
      );
      for (const m of res.body.byMerchant) {
        expect(m.seenOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      }
    });
  });

  it('kategori kırılımı seri döndürüyor', async () => {
    const res = await request(app)
      .get('/index/by-category')
      .set(auth())
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Bu test kullanıcısının tek kategorisi var (süt/yumurta kalemleri).
    if (res.body.length) {
      const first = res.body[0];
      expect(first).toHaveProperty('code');
      expect(first).toHaveProperty('name');
      expect(Array.isArray(first.series)).toBe(true);
      // Zincirin ilk halkası her zaman 100.
      expect(first.series[0].level).toBe(100);
      // Liste en yüksek seviyeden başlıyor.
      const levels = res.body.map((c: { latestLevel: number }) => c.latestLevel);
      expect([...levels].sort((a: number, b: number) => b - a)).toEqual(levels);
    }
  });

  // Bu test bir kez düşmüş bir hatayı tutuyor: pg, DATE sütununu YEREL
  // geceyarısı Date'i yapıyor ve JSON'a giderken toISOString() onu UTC'ye
  // çeviriyordu. UTC+3'te ayın 1'i bir önceki ayın 31'ine kayıyor, ekranda
  // Ağustos seviyesi "Temmuz" diye etiketleniyordu. Aylar artık SQL'de
  // metne çevriliyor; her ay ayın ilk günü olmalı.
  it('kırılım ayları saat diliminden kaymıyor', async () => {
    const res = await request(app)
      .get('/index/by-category')
      .set(auth())
      .expect(200);
    for (const c of res.body) {
      for (const p of c.series) {
        expect(p.month, 'ay, ayın ilk günü olmalı').toMatch(/^\d{4}-\d{2}-01$/);
      }
    }
  });

  it('marka kırılımında markasız kalem yok', async () => {
    const res = await request(app)
      .get('/index/by-brand')
      .set(auth())
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Markasız kalemler (kasada tartılan sebze) bu seride hiç görünmemeli.
    for (const b of res.body) {
      expect(b.name).toBeTruthy();
      expect(b.brandId).toBeTruthy();
    }
  });

  it('grupta gözlem yoksa fiyat dağılımı 404', async () => {
    const bos = await one<{ id: string }>(
      `SELECT id FROM product_groups WHERE name = 'Diş macunu'`,
    );
    await request(app)
      .get(`/products/groups/${bos.id}/spread`)
      .set(auth())
      .expect(404);
  });

  it('başka kullanıcının fişi görünmez', async () => {
    const other = await request(app)
      .post('/auth/dev-login')
      .send({ email: `other-${Date.now()}@sepet.test` });
    const mine = await request(app).get('/receipts').set(auth()).expect(200);
    const theirs = await request(app)
      .get('/receipts')
      .set({ Authorization: `Bearer ${other.body.token}` })
      .expect(200);

    expect(mine.body.length).toBeGreaterThan(0);
    expect(theirs.body).toHaveLength(0);

    await request(app)
      .get(`/receipts/${mine.body[0].id}`)
      .set({ Authorization: `Bearer ${other.body.token}` })
      .expect(404);

    await query(`DELETE FROM users WHERE id = $1`, [other.body.userId]);
  });

  // Profil ekranındaki "Hesabı sil" düğmesi sunucuya hiç istek atmıyordu:
  // sadece oturumu kapatıyor, ekranda ise "kalıcı olarak silinir" yazıyordu.
  // Aşağıdakiler o sözün gerçekten tutulduğunu tutuyor.
  // Seriler şimdilik elle giriliyor: TÜİK'in kendi portalı otomatik erişime
  // kapalı, resmî kanal olan TCMB EVDS ise API anahtarı istiyor. Sayı
  // uydurmak seçenek değil, o yüzden bu yol ürünün parçası.
  // İlk açılışta ekranın bomboş kalmaması için: resmî seri kullanıcının
  // verisine bağlı değil, endeksi olmayan hesapta da gönderilmeli.
  it('endeksi olmayan hesapta da resmî seri geliyor', async () => {
    const email = `bos-${Date.now()}@sepet.test`;
    const login = await request(app).post('/auth/dev-login').send({ email });
    const fresh = { Authorization: `Bearer ${login.body.token}` };

    const res = await request(app).get('/index').set(fresh).expect(200);
    expect(res.body.headline, 'fişi yok, manşet olmamalı').toBeNull();
    expect(res.body.series).toHaveLength(0);
    expect(res.body.official.length, 'resmî seri yine de gelmeli')
      .toBeGreaterThan(0);
    // Alan adları istemcinin beklediği biçimde olmalı. İlk yazışta çevirme
    // yalnızca dolu daldaydı; boş dalda ham satır gidiyor ve girilmiş TÜİK
    // sayısı ekranda "—" görünüyordu.
    const tuik = res.body.official.find(
      (s: { code: string }) => s.code === 'TUIK_TUFE',
    );
    expect(tuik).toHaveProperty('isOfficial');
    expect(tuik).toHaveProperty('yoyPct');

    await query(`DELETE FROM users WHERE lower(email) = $1`, [email]);
  });

  describe('Resmî seriler', () => {
    it('girdisi olmayan seri de listede görünüyor', async () => {
      const res = await request(app).get('/official').set(auth()).expect(200);
      const codes = res.body.map((s: { code: string }) => s.code);
      expect(codes).toContain('TUIK_TUFE');
      // ENAG kaldırıldı: alan adı artık kayıtlı değil, yeni adresleri de
      // ayakta değil ve hiçbir zaman makine okunur bir akışları olmadı.
      expect(codes).not.toContain('ENAG_ETUFE');
    });

    it('ay yazılıyor ve düzeltilebiliyor', async () => {
      await request(app)
        .put('/official/TUIK_TUFE/2026-07-01')
        .set(auth())
        .send({ yoyPct: 33.5 })
        .expect(200);

      // Aynı ay ikinci kez yazılınca yeni kayıt açılmıyor, düzeltiliyor.
      const fixed = await request(app)
        .put('/official/TUIK_TUFE/2026-07-01')
        .set(auth())
        .send({ yoyPct: 34.1 })
        .expect(200);
      expect(fixed.body.yoyPct).toBe(34.1);

      const res = await request(app).get('/official').set(auth()).expect(200);
      const tuik = res.body.find((s: { code: string }) => s.code === 'TUIK_TUFE');
      const july = tuik.entries.filter(
        (e: { month: string }) => e.month === '2026-07-01',
      );
      expect(july, 'ay tekil olmalı').toHaveLength(1);
      expect(july[0].yoyPct).toBe(34.1);
    });

    it('saçma değeri reddediyor', async () => {
      await request(app)
        .put('/official/TUIK_TUFE/2026-07-01')
        .set(auth())
        .send({ yoyPct: 5000 })
        .expect(400);
      await request(app)
        .put('/official/TUIK_TUFE/2026-07-01')
        .set(auth())
        .send({ yoyPct: 'otuz' })
        .expect(400);
    });

    // Ayın ilk günü şart: aynı ay iki farklı günle iki kayıt olurdu.
    it('ayın ilk günü olmayan tarihi reddediyor', async () => {
      await request(app)
        .put('/official/TUIK_TUFE/2026-07-15')
        .set(auth())
        .send({ yoyPct: 33.5 })
        .expect(400);
    });

    it('olmayan seriyi reddediyor', async () => {
      await request(app)
        .put('/official/YOK/2026-07-01')
        .set(auth())
        .send({ yoyPct: 10 })
        .expect(404);
    });

    it('yanlış girilen ay silinebiliyor', async () => {
      await request(app)
        .put('/official/TUIK_TUFE/2026-05-01')
        .set(auth())
        .send({ yoyPct: 58.2 })
        .expect(200);
      await request(app)
        .delete('/official/TUIK_TUFE/2026-05-01')
        .set(auth())
        .expect(200);
      await request(app)
        .delete('/official/TUIK_TUFE/2026-05-01')
        .set(auth())
        .expect(404);
    });
  });

  describe('Veri silme', () => {
    it('fişleri siliyor, hesabı bırakıyor', async () => {
      const before = await request(app).get('/receipts').set(auth()).expect(200);
      expect(before.body.length).toBeGreaterThan(0);

      const res = await request(app).delete('/receipts').set(auth()).expect(200);
      expect(res.body.deletedReceipts).toBe(before.body.length);

      const after = await request(app).get('/receipts').set(auth()).expect(200);
      expect(after.body).toHaveLength(0);

      // Türetilmiş endeks fişe değil kullanıcıya bağlı; basamak onu
      // götürmüyor, elle temizlenmesi gerekiyordu.
      const index = await request(app).get('/index').set(auth()).expect(200);
      expect(index.body.series).toHaveLength(0);
      expect(index.body.headline).toBeNull();

      // Hesap duruyor: jeton hâlâ geçerli.
      await request(app).get('/products').set(auth()).expect(200);
    });

    it('hesabı silince jeton artık iş görmüyor', async () => {
      await request(app).delete('/account').set(auth()).expect(200);
      await request(app).get('/receipts').set(auth()).expect(401);
    });
  });
});
