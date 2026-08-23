<h1 align="center">Sepet</h1>

<p align="center">
  <strong>Fişlerinden kendi enflasyonunu hesaplayan mobil uygulama.</strong><br>
  TÜİK herkes için tek bir sepeti varsayar. Seninki o değil.
</p>

<p align="center">
  <a href="https://github.com/KaanCan1/Sepet/actions/workflows/ci.yml">
    <img src="https://github.com/KaanCan1/Sepet/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.47.1-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/iOS-16%2B-000000?logo=apple&logoColor=white" alt="iOS">
  <img src="https://img.shields.io/badge/Android-8%2B-3DDC84?logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/lisans-MIT-16181A" alt="MIT">
</p>

<p align="center">
  <img src="docs/screenshots/01-endeks.png" width="196" alt="Endeks ekranı">
  <img src="docs/screenshots/07-kirilim.png" width="196" alt="Kategori ve marka kırılımı">
  <img src="docs/screenshots/02-fis.png" width="196" alt="Fiş ekranı">
  <img src="docs/screenshots/03-urun-gecmisi.png" width="196" alt="Ürün geçmişi ekranı">
</p>

<p align="center">
  <sub><b>Endeks</b> · <b>Kırılım</b> · <b>Fiş</b> · <b>Ürün geçmişi</b></sub>
</p>

<p align="center">
  <img src="docs/screenshots/09-ilk-acilis.png" width="196" alt="İlk açılış ekranı">
  <img src="docs/screenshots/00-karsilama.png" width="196" alt="Karşılama ekranı">
  <img src="docs/screenshots/04-aylik-kart.png" width="196" alt="Aylık kart ekranı">
  <img src="docs/screenshots/08-profil.png" width="196" alt="Profil ekranı">
</p>

<p align="center">
  <sub><b>İlk açılış</b> · <b>Karşılama</b> · <b>Aylık kart</b> · <b>Profil</b></sub>
</p>

---

## Neyi çözüyor

Resmî enflasyon rakamı, ülke ortalamasını temsil eden sabit bir mal sepetinin
fiyat değişimi. Ama sen o sepeti almıyorsun. Kirada mı oturuyorsun, arabanla mı
işe gidiyorsun, çocuğun var mı — hepsi senin sepetini ortalamadan uzaklaştırıyor.

Sepet, market fişlerini okuyup **senin fiilen aldığın ürünlerden** bir fiyat
endeksi kuruyor ve resmî ölçümün yanına koyuyor. Hiçbirini
doğrulamıyor ya da yorumlamıyor — sadece referans çizgisi olarak duruyorlar.

## Çekirdek döngü

**tara → eşle → ölç → paylaş**

| | Ekran | İş |
|---|---|---|
| **00** | Karşılama | Apple, Google ya da e-posta ile giriş. Sağlayıcı akışı henüz sahte; jetonu üreten uç değişecek, saklayan katman aynı kalacak. |
| **01** | Endeks | Tek sayı: son 12 ayda senin sepetin. Altında TÜİK karşılaştırması, seri grafiği ve son fişler. |
| **02** | Fiş ekleme ve fiş | Fotoğraf → cihaz üstünde OCR → düzeltilebilir taslak → kayıt. Fişin kâğıt hâli ve altında yorumlanmış satırlar; emin olunamayan satır `eşleşme?` ile işaretlenir. |
| **03** | Ürün geçmişi | Tek ürünün gözlem geçmişi, marketler arası son fiyatlar, 12 aylık değişim. |
| **04** | Aylık kart | Paylaşılabilir özet kart (PNG olarak dışa aktarılır) ve ayın en çok zamlanan kalemleri. |
| **05** | Kırılım | Hangi kategori, hangi marka. Her seri kendi kümesinde yeniden ağırlıklandırılıyor — yüzdeler birbirine eklenmez. |

Fiş yokken ekran boş kalmıyor: yapılacak tek iş, tek bir birincil eylem ve
zaten bağımsız olan resmî karşılaştırma çizgisi gösteriliyor.

Yanlarında: fiş ve ürün listeleri, fiş detayı, profil ve oturum, KVKK aydınlatma
ve açık rıza ekranları.

## Mimari

<p align="center">
  <img src="docs/diagrams/mimari.svg" width="880" alt="Sepet mimarisi: fişin fotoğrafı cihazdan çıkmıyor, sunucuya yalnızca eşleşmiş satırlar gidiyor, endeks Postgres fonksiyonlarında hesaplanıyor">
</p>

Kesikli çerçeve bilerek orada: **fişin fotoğrafı cihaz sınırını geçmiyor.**
Metin cihaz üstünde okunuyor, sunucuya yalnızca eşleşmiş satırlar gidiyor —
ürün, tutar, tarih. KVKK'daki veri minimizasyonu bir politika metni değil,
mimarinin bir özelliği.

Mavi kutu ikinci karar: **endeks uygulama kodunda değil, verinin yanında.**
Dört SQL fonksiyonu, tek işlemde:

<p align="center">
  <img src="docs/diagrams/endeks-hatti.svg" width="920" alt="Laspeyres endeksinin dört SQL aşaması ve her birinin engellediği hata">
</p>

Gri satırlar o aşama olmasaydı sayıya ne olacağını söylüyor. Şemaların
kaynağı ve renk eşlemesi: [`docs/diagrams/`](docs/diagrams/).

## Projenin kalbi: `eşleşme?`

<img src="docs/screenshots/05-eslesme.png" width="230" align="right" alt="Eşleşme onayı alt sayfası">

Fişteki `YUMURTA 30LU` satırı hangi kanonik ürüne gidiyor? 30'lu yumurta mı,
15'li mi? Normalizasyon emin olamadığında uygulama **tahmin etmiyor, soruyor.**

Bunun iki karşılığı var:

**Doğruluk.** Yanlış eşleşme endeksi sessizce bozar — kullanıcı hiç fark etmez.
Soru sormak bozmaz.

**Maliyet.** Her fiş satırı için bir dil modeli çağırmak, kullanıcı başına aylık
maliyeti hızla anlamsızlaştırır. Bu mimaride OCR cihaz üstünde ve bedava; model
yalnızca belirsizlik çözücü olarak devreye giriyor. Onaylanan eşleşme market fiş
formatı bazında önbelleğe alınıyor — aynı format bir daha sorulmuyor.

<br clear="right">

## Tasarım

İki katman:

**İçerik — kâğıt fiş.** Başlıklar serif, sayılar monospace: uygulamanın malzemesi
kâğıt fiş olduğu için. Renk tek yerde harcanıyor, zam kırmızısında. Paylaşım
kartının tırtıklı kenarı fişin koparma çizgisi.

**Krom — iOS 26 Liquid Glass.** Üst bar, alt sayfalar ve yüzen kapsül sekme
çubuğu (ondan ayrık kamera düğmesiyle) arkasını bulanıklaştırıyor, üst kenarında
ışık topluyor. İçerik camın altından akıyor.

Serif ve mono fontlar depoya gömülü — Source Serif 4 ve IBM Plex Mono, ikisi de
OFL. Sistem fontlarına güvenilseydi Android tarafında tipografi çökerdi.

## Yığın

| Katman | Seçim | Neden |
|---|---|---|
| İstemci | **Flutter 3.47** (FVM ile sabit) | Tek kod tabanı, iki mağaza |
| Vitrin tipografisi | **Montserrat** | Gotham'ın (Obama 2008 kampanyası) ücretsiz en yakın karşılığı — kelime işareti, manşet sayı ve büyük başlıklarda |
| OCR | **Apple Vision** (cihaz üstünde) | Fişin fotoğrafı cihazdan çıkmıyor. ML Kit yerine Vision: ek pod yok, Apple Silicon simülatöründe de çalışıyor |
| Krom | **liquid_glass_widgets** | Yüzen kapsül ve daire düğme gerçek kırılma/speküler kenar ile — elle yazılmış `BackdropFilter` taklidi değil |
| Normalizasyon | **Claude API**, yalnızca belirsiz satırlar | Maliyeti gözlem başına değil, belirsizlik başına ödemek |
| Backend | **Node.js/Express + PostgreSQL** | Kullanıcı, fiş, kanonik ürün, alias tablosu, fiyat gözlemleri, Laspeyres endeksi |
| Karşılaştırma | TÜİK TÜFE aylık serisi | Resmî sayı, yorumsuz; senin sayının yanında referans çizgisi |

> API anahtarı hiçbir koşulda istemciye gömülmüyor — derlenmiş uygulamadan
> çıkarılabilir. Her model çağrısı kendi backend'imiz üzerinden geçiyor.

> [!NOTE]
> Bu depoda şu an **arayüz katmanı ve demo verisi** var. Backend, gerçek OCR ve
> veri çekimi yol haritasında. Modeller backend'e geçerken değişmeyecek şekilde
> ayrıldı.

## KVKK

Fiş verisi kişisel veridir; uygulama buna göre kurgulandı.

- **Fişin fotoğrafı sunucuya gitmiyor.** Metin cihaz üstünde okunuyor, görsel iş
  bitince siliniyor. Sunucuya yalnızca eşleşmiş satırlar gidiyor.
- **Hesap hizmeti açık rızaya dayanmıyor**, sözleşmenin ifasına (KVKK m. 5/2-c).
  Rıza ancak *hayır diyebiliyorsan* geçerlidir; hizmetin kendisini rızaya
  bağlamak yanlış olurdu.
- **Aydınlatma ve açık rıza ayrı ekranlarda.** Kurul'un 18.02.2026 tarihli
  [2026/347 sayılı ilke kararı][kvkk-347] ikisinin tek metinde birleştirilmesini
  yasaklıyor. İki isteğe bağlı izin (anonim endekse katkı, pazarlama) varsayılan
  kapalı ve her an geri alınabilir.
- **Özel nitelikli veri toplanmıyor.** Alışveriş kaydı bu kapsamda değil; ilaç ve
  reçete satırları endekse dahil edilmiyor.

Bir test bunu koruma altına alıyor: aydınlatma ekranında hiçbir onay anahtarı
bulunmadığını doğruluyor.

[kvkk-347]: https://www.kvkk.gov.tr/Icerik/8710/veri-sorumlulari-tarafindan-acik-riza-ve-aydinlatma-metinlerinin-ayri-ayri-duzenlenmesi-gerektigi-hakkinda-kisisel-verileri-koruma-kurulunun-18-02-2026-tarihli-ve-2026-347-sayili-ilke-karari

## Çalıştırma

Proje Flutter sürümü [`.fvmrc`](.fvmrc)'de sabit ve [FVM][fvm] ile bağlanıyor —
makinendeki global kuruluma dokunmadan. CI de sürümü aynı dosyadan okuyor, yani
yerel ile CI'ın ayrışması mümkün değil.

```bash
brew tap leoafarias/fvm && brew install fvm
fvm use                  # .fvmrc'deki sürümü kurar
fvm flutter run
```

Denetimler — CI'ın çalıştırdığının birebir aynısı:

```bash
./tool/check.sh
```

> Betik biçimlendirmeyi projeye bağlı Flutter'ın Dart'ıyla yapar ve sürüm
> uyuşmazlığında uyarır. Çıplak `dart format` sistemdeki başka bir Dart SDK'sını
> çalıştırıp yerelde temiz görünen kodu CI'da patlatabiliyor.

[fvm]: https://fvm.app

## Katkı akışı

`main` her zaman yeşil: doğrudan push kapalı, her değişiklik PR üzerinden geçiyor
ve CI yeşile dönmeden birleştirilemiyor.

```
main ──────────────●───────────●──────►
                  ╱           ╱
   feat/ocr ─────●           ╱
   fix/tab-bar ──────────────●
```

- Dal adları: `feat/…`, `fix/…`, `chore/…`, `docs/…`
- [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(scan): eşleşme onayı alt sayfası`
- **Squash merge** — `main` doğrusal kalıyor, her PR tek commit
- Birleşen dal otomatik siliniyor

```bash
git switch -c feat/ocr
# ...
./tool/check.sh
git push -u origin feat/ocr
gh pr create --fill
```

**CI** her PR'da: `dart format` denetimi → `flutter analyze --fatal-infos` →
`flutter test --coverage` → Android (APK) ve iOS (`--no-codesign`) derlemeleri.

**Release**, `v*.*.*` etiketi atıldığında APK + AAB üretip GitHub Release'e
ekliyor. TestFlight adımı imzalama sertifikaları eklenene kadar atlanıyor.

## Proje yapısı

```
lib/
├── data/          modeller, biçimlendirme, API istemcisi, depo
├── state/         cubit'ler — oturum, endeks, fişler, ürünler, kırılım
├── screens/       ekranlar
├── theme/         tasarım belirteçleri (renk, tipografi)
└── widgets/       cam yüzeyler, grafik motoru, çizgi ikonlar, ekran kabuğu
```

Her iki grafik de tek bir `CustomPainter` üzerinde; ikonlar SVG değil, çizim.

**Durum yönetimi: Bloc (Cubit).** Uygulama durumu — oturum, endeks, fiş
listesi, ürünler, kırılım — widget ağacının dışında, `lib/state/` altındaki
cubit'lerde. Böylece uygulamayı ayağa kaldırmadan, kare beklemeden birim
testi yazılabiliyor (`test/cubit_test.dart`).

Sunucudan veri çeken her ekran aynı üç hâli yaşıyor, o yüzden ortak bir taban
var: `DataCubit<T>` yalnızca `fetch()` istiyor, hata yakalamayı ve
`DataLoading / DataFailure / DataReady` geçişlerini kendisi yapıyor. Durumlar
mühürlü sınıf, yani derleyici eksik dal bırakılmasına izin vermiyor ve "hem
yükleniyor hem hatalı" gibi geçersiz bileşimler kurulamıyor.

`setState` tamamen kalkmadı, kalkmamalı da: sekme indeksi, basılma
animasyonu, açılır pencerenin açıklığı gibi tek bir widget'ın içinde doğup
ölen geçici durumlar yerinde duruyor. Bloc'a taşınan şey uygulama durumu.

Sekme ekranlarının cubit'leri kabuğun üstünde, ayrıntı ekranlarınınki
yönlendirmeyle birlikte doğup ölüyor. Sebebi somut: fiş eklendiğinde hem
endeks hem fiş listesi bayatlıyor, ikisi ekrana bağlı olsaydı sekme
değiştirmeden tazelenemezlerdi.

## Telefona kurmak

Uygulama sunucunun adresini derleme zamanında alıyor:

```bash
SEPET_API_URL=https://sepet-api.onrender.com ./tool/run-device.sh
```

iPhone'da önce **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu** açık
olmalı. Ücretsiz Apple ID ile imzalama profili **7 gün** geçerli; süre dolunca
aynı komut yeniden çalıştırılır. Apple Developer Program üyeliğiyle bu süre bir
yıla çıkıyor ve TestFlight açılıyor.

> iOS'un ATS kuralı düz HTTP'ye izin vermiyor — adres HTTPS olmak zorunda.
> Render ve Neon ikisi de HTTPS veriyor.

## Sunucu

Endeksin veri modeli ve hesabı [`server/`](server/) altında. Laspeyres mantığı
uygulama kodunda değil **SQL fonksiyonlarında** duruyor — dört aşama: aykırı
eleme, aylık medyan + boşluk doldurma, harcama payı ağırlıkları, zincirleme.

```bash
brew services start postgresql@14 && createdb sepet
cd server && npm install && npm run migrate:up && npm test
```

Ayrıntı ve bilinen sınırlar: [server/README.md](server/README.md)

## Yol haritası

- [ ] Gerçek kamera + ML Kit / Vision OCR
- [ ] Node/Express + Postgres backend, JWT oturum
- [ ] Kanonik ürün + alias şeması, Laspeyres endeks SQL'i
- [ ] TÜİK TÜFE serisinin TCMB EVDS üzerinden aylık çekimi
- [ ] Ayın 3'ünde aylık kart bildirimi
- [ ] App Store / Play Store yayını

## Lisans

MIT — bkz. [LICENSE](LICENSE). Gömülü fontların lisansları:
[assets/fonts/LICENSES.md](assets/fonts/LICENSES.md).
