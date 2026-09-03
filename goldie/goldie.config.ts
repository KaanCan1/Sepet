import type { GoldieConfig } from "goldie/dist/config.d.ts";

/**
 * App Store görselleri. `GOLDIE_CONFIG=goldie/goldie.config.ts goldie all`
 *
 * Akışlar `.argent/flows/store-*.yaml` içinde ve elle de çalıştırılabiliyor:
 * `argent flow run store-02-fis`.
 *
 * İKİ ÖNKOŞUL:
 *
 *  1. Yerel sunucu ayakta olmalı (`cd server && npm start`). Uygulama
 *     varsayılan olarak http://localhost:4000 adresine bakıyor ve ekranların
 *     tamamı gerçek veriyle doluyor — vitrin hesabında 22 fiş, 11 ay var:
 *       cd server && npm run seed -- vitrin@sepet.app --vitrin
 *  2. Derleme SEPET_DEMO_EMAIL bayrağıyla yapılmalı:
 *     fvm flutter build ios --simulator --debug \
 *       --dart-define=SEPET_DEMO_EMAIL=vitrin@sepet.app
 *     goldie her akıştan önce uygulamayı verisi silinmiş kuruyor; bu bayrak
 *     olmadan her akış giriş ekranında kalıyor. Bayrak yalnızca hata ayıklama
 *     derlemesinde çalışıyor, yayın derlemesinde ölü.
 *
 * README'deki boş ilk açılış ekranı (docs/screenshots/ilk-acilis.png)
 * üçüncü bir hesap istiyor: hiç fişi olmayan biri. Bayrağı
 * vitrin-bos@sepet.app'e çevirip derlemek yetiyor — dev-login hesabı
 * yoksa açıyor. Keychain'deki eski jeton bunu es geçirir; uygulama içinden
 * "Çıkış yap" deyip yeniden açmak jetonu temizlemenin en kolay yolu.
 *
 * NEDEN demo@sepet.app DEĞİL: inceleme hesabı eşleşme akışını göstermek için
 * bilerek bekleyen satır taşıyor, üstüne bir de elle taranmış gerçek bir
 * Migros fişi var. İkisi endeks ekranının tepesine kırmızı "10 kalem endekse
 * girmiyor" şeridi bastırıyordu — uyarı doğru ama vitrinde ilk okunan üçüncü
 * satır oluyordu. Vitrin hesabı aynı sepeti bekleyen satır olmadan kuruyor.
 *
 * goldie yayın (Release) derlemesi istiyor; gerekçesi React Native'in LogBox
 * şeritleri. Flutter'da o şerit yok ve uygulama zaten debugShowCheckedModeBanner
 * kullanmıyor — hata ayıklama derlemesi görsel olarak temiz, doğrulandı.
 */
const APP_ROOT = "/Users/kaancankurt/dev/market";

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  appPath: `${APP_ROOT}/build/ios/iphonesimulator/Runner.app`,
  bundleId: "com.kaancankurt.sepet",

  devices: ["iphone-6.9"],
  locales: ["tr-TR"],
  appearance: "light",

  frame: { variant: "17-pro-silver" },

  theme: {
    // Kâğıt fiş tonunda, çok yumuşak. Referanslardaki gibi düz denecek kadar
    // az geçişli — doygun zemin ekranları eziyor.
    background: "linear-gradient(180deg, #F7F3ED 0%, #EDE8E1 100%)",
    headlineColor: "#141719",
    subheadColor: "#6B7075",
    // Paketle gelen font. Sistem yığını goldie'nin çizicisinde çözülmüyordu
    // ve Türkçe glifleri düşüyordu: "Fişin" → "Fi▯in", "resmî" → "resm▯".
    // DM Sans Latin Extended-A taşıyor, yani ş/ç/î/ğ/ı hepsi yerinde.
    fontFamily: '"DM Sans", -apple-system, system-ui, sans-serif',
    copyHeightRatio: 0.22,
    deviceWidthRatio: 0.82,
    // Şablon yok: beş kare de aynı ritimde. Sade istenen buydu — kare kare
    // yerleşim değiştiren bir şerit App Store'da tek tek bakıldığında
    // dağınık duruyor.
    layout: "classic",
  },

  store: {
    name: "Sepet",
    subtitle: { "tr-TR": "Kendi enflasyonunu ölç" },
    developer: "Kaan Can Kurt",
    category: "Finance",
    rating: 4.8,
    ratingCount: "—",
    ageRating: "4+",
    price: "Ücretsiz",
    description: {
      "tr-TR":
        "TÜİK herkes için tek bir sepet varsayar. Seninki o değil. Sepet, " +
        "market fişlerinden senin kendi enflasyon endeksini hesaplar ve " +
        "resmî ölçümün yanına koyar.\n\n" +
        "Fişin fotoğrafı telefonundan çıkmaz; metin cihaz üstünde okunur. " +
        "Hesabına yalnızca eşleşmiş satırlar gider: ürün, tutar, tarih, market.",
    },
  },

  scenes: [
    {
      kind: "screenshot",
      id: "endeks",
      flow: "store-01-endeks",
      headline: { "tr-TR": "Kendi enflasyonun" },
      subhead: {
        "tr-TR": "Fişlerinden hesaplanan tek sayı, TÜİK'in yanında.",
      },
    },
    {
      kind: "screenshot",
      id: "fis",
      flow: "store-02-fis",
      headline: { "tr-TR": "Fişin kendisi duruyor" },
      subhead: {
        "tr-TR": "Fotoğraf telefonundan çıkmıyor; metin cihazda okunuyor.",
      },
    },
    {
      kind: "screenshot",
      id: "kirilim",
      flow: "store-03-kirilim",
      headline: { "tr-TR": "Hangi kategori zamlandı" },
      subhead: {
        "tr-TR": "Et, ekmek, süt — kendi sepetindeki paylarına göre.",
      },
    },
    {
      kind: "screenshot",
      id: "urun",
      flow: "store-04-urun",
      headline: { "tr-TR": "Tek ürünün 11 aylık yolu" },
      subhead: { "tr-TR": "Dört markette gördüğün son fiyatlar yan yana." },
    },
    {
      kind: "screenshot",
      id: "kart",
      flow: "store-05-kart",
      headline: { "tr-TR": "Ayın özeti, paylaşılabilir" },
      subhead: {
        "tr-TR": "Her ayın 3'ünde, resmî veri açıklandığında hatırlatılır.",
      },
    },

    // App Preview videosu. Apple çerçeve, başlık ve altyazı istemiyor —
    // klipler kaydedildiği gibi arka arkaya ekleniyor, yani hikâyeyi
    // akışların kendisi anlatmak zorunda. Sıra kareler ile aynı: önce
    // "ne kadar", sonra "neyden", sonra tek ürün, en sonda paylaşılan kart.
    //
    // goldie döngüden önce bir kez restart-app yapıp bekliyor; segmentler
    // arasında yeniden kurulum YOK. Bu yüzden akışlarda launch adımı yok ve
    // her segment bir öncekinin bıraktığı ekrandan devam ediyor.
    //
    // Toplam ~25 sn ölçüldü; Apple 15-30 sn istiyor. Süre büyürse ilk
    // bakılacak yer akışlardaki sabit wait değerleri.
    //
    // Kart iki segmente bölündü. Tam ekran modalin açılması iOS'a durum
    // çubuğunu yeniden çizdiriyor ve sabitlenmiş çubuk (9:41, dolu sinyal)
    // orada düşüp gerçek saate ve sinyalsiz gri noktalara dönüyor. Segment
    // sınırı, çubuğun modal açıldıktan SONRA yeniden sabitlenip oturmasına
    // yer açıyor — bkz. tool/onizleme-kaydet.sh.
    {
      kind: "preview",
      id: "onizleme",
      segments: [
        { id: "endeks", flow: "store-preview-01-endeks" },
        { id: "kirilim", flow: "store-preview-02-kirilim" },
        { id: "urun", flow: "store-preview-03-urun" },
        { id: "kart", flow: "store-preview-04-kart" },
        { id: "paylas", flow: "store-preview-05-paylas" },
      ],
    },
  ],
};

export default config;
