# Sepet

Fişlerinden kendi enflasyonunu hesaplayan mobil uygulama.

TÜİK ve ENAG rakamları herkes için tek bir sepeti varsayar. Senin sepetin o değil.
Sepet, market fişlerini okuyup senin fiilen aldığın ürünlerden kişisel bir fiyat
endeksi kuruyor ve resmî/bağımsız ölçümlerin yanına koyuyor — yorumsuz, sadece
referans çizgisi olarak.

## Çekirdek döngü

| | Ekran | İş |
|---|---|---|
| 01 | **Endeks** | Tek sayı: son 12 ayda senin sepetin. Altında TÜİK ve ENAG karşılaştırması, seri grafiği, son fişler. |
| 02 | **Fiş okuma** | Cihaz üstünde OCR → satırların kanonik ürünlere eşlenmesi. Emin olunamayan satır `eşleşme?` ile işaretlenir ve kullanıcıya sorulur. |
| 03 | **Ürün geçmişi** | Tek ürünün gözlem geçmişi, marketler arası son fiyatlar, 12 aylık değişim. |
| 04 | **Aylık kart** | Paylaşılabilir özet kart (PNG olarak dışa aktarılıp paylaşılır) + ayın en çok zamlanan kalemleri. |

Yanlarında: fiş listesi, ürün listesi, profil/oturum, KVKK aydınlatma ve açık rıza ekranları.

## Neden `eşleşme?` etiketi

Fişteki `YUMURTA 30LU` satırının hangi kanonik ürüne gittiğinden emin olunamadığında
uygulama kullanıcıya soruyor. Bunun iki karşılığı var:

- **Doğruluk.** Yanlış eşleşme endeksi sessizce bozar; soru sormak bozmaz.
- **Maliyet.** Her satır için LLM çağırmak kullanıcı başına aylık maliyeti anlamsızlaştırır.
  OCR cihaz üstünde ve bedava; model yalnızca belirsizlik çözücü olarak devreye giriyor,
  onaylanan eşleşme market fiş formatı bazında önbelleğe alınıyor.

## Yığın

- **Flutter (Dart)** — tek kod tabanı, iOS + Android
- **OCR: cihaz üstünde** — ML Kit Text Recognition / Apple Vision. Ücretsiz, çevrimdışı, hızlı.
- **Normalizasyon: Claude API** — yalnızca belirsiz satırlar için, kendi backend'imiz üzerinden.
  API anahtarı hiçbir koşulda istemciye gömülmez.
- **Backend: Node.js/Express + PostgreSQL** — kullanıcı, fiş, kanonik ürün, alias tablosu,
  fiyat gözlemleri ve Laspeyres endeks hesabı.
- **Karşılaştırma verisi** — TÜİK TÜFE ve ENAG E-TÜFE aylık serileri backend tarafından çekilir.

> Bu depoda şu an **arayüz katmanı ve demo verisi** var. Backend, gerçek OCR ve veri
> çekimi yol haritasında.

## Tasarım

Malzeme kâğıt fiş: başlıklar serif, sayılar monospace. Renk tek yerde harcanıyor —
zam kırmızısı. Paylaşım kartının tırtıklı kenarı fişin koparma çizgisi.
Krom (üst bar, yüzen sekme kapsülü, alt sayfalar) iOS 26 Liquid Glass diline oturuyor:
arkasını bulanıklaştıran, üst kenarında ışık toplayan yarı saydam yüzeyler.

Fontlar depoya gömülü: Source Serif 4 ve IBM Plex Mono (ikisi de OFL).

## KVKK

- Fişin **fotoğrafı sunucuya gitmiyor.** Metin cihaz üstünde okunuyor, görsel iş bitince siliniyor.
- Hesap ve endeks hizmeti **sözleşmenin ifasına** (KVKK m. 5/2-c) dayanıyor; açık rıza aranmıyor.
- Anonim endekse katkı ve pazarlama iletileri **ayrı ve isteğe bağlı açık rıza** ile,
  varsayılan kapalı. Kurul'un 18.02.2026 tarihli **2026/347** ilke kararı gereği aydınlatma
  metni ile açık rıza metni ayrı ekranlarda.
- Alışveriş kaydı özel nitelikli veri değil; ilaç/reçete satırları endekse dahil edilmiyor.

## Çalıştırma

```bash
flutter pub get
flutter run
```

Testler:

```bash
flutter test
```

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
- Commit mesajları [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(scan): eşleşme onayı alt sayfası`
- **Squash merge** — `main` doğrusal kalıyor, her PR tek commit
- Birleşen dal otomatik siliniyor

```bash
git switch -c feat/ocr
# ...
git push -u origin feat/ocr
gh pr create --fill
```

CI her PR'da şunları çalıştırıyor: `dart format` denetimi, `flutter analyze
--fatal-infos`, `flutter test --coverage`, ardından Android (APK) ve iOS
(`--no-codesign`) derlemeleri. `v*.*.*` etiketi atıldığında release iş akışı
APK + AAB üretip GitHub Release'e ekliyor.

## Yol haritası

- [ ] Gerçek kamera + ML Kit / Vision OCR
- [ ] Node/Express + Postgres backend, JWT oturum
- [ ] Kanonik ürün + alias şeması, Laspeyres endeks SQL'i
- [ ] TÜİK ve ENAG serilerinin aylık çekimi
- [ ] Ayın 3'ünde aylık kart bildirimi
- [ ] App Store / Play Store yayını

## Lisans

MIT
