# Şemalar

İki şema, ikisi de elle yazılmış SVG. Kütüphane yok, çalışma zamanı yok,
dışarıdan görsel yok — dosyayı açtığında gördüğün şey dosyanın kendisi.

| Dosya | Ne gösteriyor |
|---|---|
| [`mimari.svg`](mimari.svg) | Fişin izlediği yol: cihaz → sunucu → veritabanı |
| [`endeks-hatti.svg`](endeks-hatti.svg) | Laspeyres endeksinin dört SQL aşaması |

## Neden elle SVG

Şema kaynak koddan üretilmiyor, çünkü anlatmak istediği şey kod yapısı değil
**karar**: fotoğrafın cihaz sınırını geçmemesi, hesabın verinin yanında
durması. Otomatik üretilen bir bağımlılık grafiği bunların hiçbirini
söylemiyor — kutuları sayıyor, gerekçeyi atlıyor.

Elle yazmanın bedeli hizalamayı kendin yapmak; karşılığı her çizginin bir
şey anlatması.

## Renkler

Uygulamanın tasarım belirteçleriyle aynı ([`lib/theme/tokens.dart`](../../lib/theme/tokens.dart)):

| SVG | Belirteç | Nerede |
|---|---|---|
| `#F7F6F3` | `C.paper` | zemin |
| `#FFFFFF` | `C.card` | kutu dolgusu |
| `#16181A` | `C.ink` | metin, ok |
| `#7A7975` | `C.muted` | ikincil metin |
| `#E8E6E1` | `C.line` | kutu kenarı |
| `#46586B` | `C.ref` | vurgulanan düğüm |
| `#9F2F2D` | `C.hot` | dikkat çeken tek uyarı |

Şemalar kendi zeminini taşıyor, yani GitHub'ın açık ve koyu temasında aynı
görünüyorlar. `currentColor` kullanılmadı: README'de `<img>` olarak
gömüldükleri için sayfanın rengini devralmıyorlar.

## Kurallar

- Ok etiketsiz bırakılmıyor. Etiketsiz ok "bir şekilde ilişkili" demek;
  `yazar`, `endeks okur` bilgi.
- Kesikli çerçeve cihaz sınırı, kesikli ok henüz olmayan yol.
- Kırmızı yalnızca bir yerde: fotoğrafın durduğu nokta. Renk seyrek
  kullanılınca anlam taşıyor.
- Açıklama (legend) yalnızca aynı kodlama tekrar ediyorsa var; tek seferlik
  bir işaretin anlamı işaretin yanına yazılıyor.
