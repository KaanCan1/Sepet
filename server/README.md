# Sepet — sunucu

Kişisel enflasyon endeksinin veri modeli ve hesabı. Endeks mantığı uygulama
kodunda değil **SQL fonksiyonlarında** duruyor.

## Kurulum

Homebrew'daki PostgreSQL yeterli, ayrıca bir şey gerekmiyor:

```bash
brew services start postgresql@14
createdb sepet
npm install
npm run migrate:up
psql -d sepet -f seeds/catalog.sql   # referans katalog
npm run seed                          # 12 aylık demo hesabı
npm run dev                           # http://localhost:4000
npm test
```

## Dağıtım

Barındırma iki parça:

| Katman | Servis | Neden |
|---|---|---|
| Veritabanı | **Neon** | Render'ın ücretsiz Postgres'i 30 gün sonra siliniyor. Neon'unki kalmıyor; 5 dk sonra askıya alıyor ama uyanması milisaniye. |
| API | **Render** | `render.yaml` bir Blueprint; panelde "New → Blueprint" ile okutuluyor. |

Sırlar depoda değil, Render panelinde: `DATABASE_URL` (Neon'dan) ve
`DEV_LOGIN_EMAILS`. `JWT_SECRET` Render tarafından üretiliyor.

İkisi eksikse sunucu açılmıyor ve logda ne eksik olduğunu tek seferde yazıyor —
Render'da deploy "failed" görünüyorsa ilk oraya bak.

Her **açılışta** `deploy:prepare` çalışıyor: migration'lar + referans katalog.
İkisi de tekrar çalıştırılabilir ve node-pg-migrate danışma kilidi aldığı için
aynı anda iki örnek açılsa da yarışmıyorlar.

> Bunun doğru yeri `preDeployCommand` ama Render ücretsiz planda o adımı
> desteklemiyor. Ücretli plana geçilirse oraya taşınabilir — o zaman her
> uyanışta değil yalnızca dağıtımda çalışır.

### Giriş neden hâlâ dev-login

Gerçek Apple/Google akışı Apple Developer üyeliği ve Google istemci kimlikleri
alınınca gelecek. O zamana kadar dağıtılmış sunucuya girmenin tek yolu
`/auth/dev-login`. Üretimde bu ucu herkese açık bırakmak isteyen herkese hesap
açmak demek olurdu; bu yüzden `DEV_LOGIN_EMAILS` listesi zorunlu — liste boşsa
sunucu açılışta hata verip duruyor.

## Uçlar

| Uç | İş |
|---|---|
| `POST /auth/dev-login` | Sağlayıcısız geliştirme girişi. Üretimde kapalı (`DEV_LOGIN`). |
| `GET /index` | Ekran 01: manşet, kendi serin, resmî seriler. |
| `GET /index/movers` | Ekran 04: bu ay en çok zamlananlar. |
| `GET /receipts` · `GET /receipts/:id` | Fiş listesi ve satır kırılımı. |
| `POST /receipts` | Fiş kaydı. Satırlar tek işlemde yazılır, sonra endeks tazelenir. |
| `POST /receipts/:id/lines/:lineId/match` | "eşleşme?" cevabı — alias'a da yazılır. |
| `GET /products` · `GET /products/:id` | Ekran 03. |
| `GET /products/catalog/search?q=` | Eşleşme adayları. |

Kimlik doğrulama Bearer JWT. Gerçek Apple/Google akışı geldiğinde değişen tek
yer token'ı **üreten** uç olacak; doğrulayan katman aynı kalıyor.

### Demo hesabı

`npm run seed` 12 aylık geçmişi olan `demo@sepet.app` kullanıcısını kuruyor:
24 fiş, 200 satır, iki tanesi bilerek `pending` bırakılmış ki "eşleşme?" akışı
demo hesapta da görünsün. App Store incelemesine bu hesap verilecek — boş kabuk
gönderilen uygulamalar "minimum functionality" gerekçesiyle geri dönüyor.

`gen_random_uuid()` PostgreSQL 13'ten beri çekirdekte — eklenti kurmaya gerek yok.

## Endeks nasıl hesaplanıyor

Klasik Laspeyres baz dönem sepetini sabit tutar:

```
P = Σ(p_i,t · q_i,0) / Σ(p_i,0 · q_i,0)
```

Kişisel veride bu çalışmaz: baz dönem miktarları seyrek ve gürültülü. Cebirsel
olarak özdeş olan **harcama payı ağırlıklı fiyat oranları** formu kullanılıyor —
ağırlıklar fişten doğrudan çıkıyor ve bir ürün o ay yoksa ağırlık yeniden
normalize edilerek düşülüyor:

```
L_t = Σ_{i∈M_t} w_i,t · (p_i,t / p_i,t-1)     M_t = t ve t-1'de fiyatı olanlar
I_t = I_{t-1} · L_t                            I_ilk = 100
12 aylık değişim = (I_t / I_{t-12} - 1) · 100
```

Sabit baz yerine **zincirleme** kullanılıyor, çünkü sepet kayıyor: yeni almaya
başladığın ürünün baz dönemde fiyatı yok. Zincirleme sepetin evrilmesine izin
verir.

### Dört aşama

| Fonksiyon | İş |
|---|---|
| `flag_outliers` | Gözlemi aynı üründeki *diğer* gözlemlerin medyanına oranlar; sınır dışındaysa eler. Kendi kendini medyana katmaz — iki gözlemden biri bozuksa ikisi de normal görünürdü. |
| `rebuild_monthly_prices` | Aylık **medyan** (ortalama değil: promosyon ayı bükmesin) + boşluk doldurma. Gözlem yoksa son fiyat taşınır, oran 1.0 olur. Taşıma 6 ayı geçerse satır üretilmez. |
| `rebuild_weights` | Harcama payı. Pencere cari ayı **dışarıda** bırakır; yoksa bu ay çok aldığın şey kendi ağırlığını şişirir. |
| `rebuild_index_levels` | Aylık halka ve kümülatif seviye. Postgres'te kümülatif çarpım penceresi olmadığı için `exp(Σ ln)`. |

Hepsi `refresh_user_index(user_id)` ile sırayla çalışır.

### Birim fiyat

Fiyat oranı paket fiyatı üzerinden değil **birim fiyat** üzerinden hesaplanır;
yoksa 1 L yerine 2 L alan kullanıcıda sahte enflasyon çıkar.

```
unit_price = line_amount / (quantity × canonical.size_value)
```

| Fiş satırı | quantity | unit | size_value | unit_price |
|---|---|---|---|---|
| `SUT TAM YAGLI 1L` ×3 → 116,70 | 3 | litre | 1 | 38,90 TL/L |
| `DOMATES KG 1,240` → 92,88 | 1,240 | kilogram | 1 | 74,90 TL/kg |
| `YUMURTA 30LU` → 184,50 | 1 | adet | 30 | 6,15 TL/adet |

Yumurta satırı uygulamadaki `eşleşme?` etiketinin neden kritik olduğunu
gösteriyor: 30'lu mu 15'li mi sorusunun cevabı `size_value`'yu, o da birim
fiyatı belirliyor.

## Bilinen sınırlar

- **Paket değişimi.** 30'lu ve 15'li yumurta ayrı kanonik ürün; kullanıcı
  birinden diğerine geçerse biri bayatlar, öbürü sıfırdan başlar ve sepet
  parçalanır. `substitute_group_id` alanı ileride birim fiyat üzerinden
  zincirlemek için şimdiden duruyor.
- **Mevsimsellik.** Taze ürün fiyatları mevsime göre oynuyor; endeks bunu
  düzeltmiyor.
- **Market değişimi.** Endeks fiilen ödenen fiyatı ölçüyor, yani daha ucuz
  markete geçmek endeksi düşürüyor. Bu kasıtlı: ölçülen şey senin gerçek yaşam
  maliyetin.

## KVKK

Fişin tam OCR metni **saklanmıyor** — hesap için gereken tek şey eşleşmiş
satırlar, ham metin fazladan kişisel veri olurdu. Kullanıcıya bağlı her tabloda
`ON DELETE CASCADE` var; hesap silindiğinde veri gerçekten siliniyor.
