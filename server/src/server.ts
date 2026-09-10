import { createApp } from "./app.js";
import { env } from "./env.js";
import { refreshOfficial } from "./official/refresh.js";
import { refreshReference } from "./reference/refresh.js";

createApp().listen(env.port, () => {
  console.log(`Sepet sunucusu http://localhost:${env.port}`);

  // TÜİK TÜFE'yi arka planda tazele.
  //
  // Bekletmeden: Render ücretsiz katmanda servis her uyanışta baştan
  // başlıyor ve TCMB'yi beklemek soğuk açılışı uzatırdı.
  //
  // refreshOfficial kendi tazelik kontrolünü yapıyor; seri ayda bir
  // açıklandığı için 20 günden yeni veri varsa ağa hiç çıkmıyor. Anahtar
  // tanımlı değilse sessizce atlıyor — elle giriş yolu duruyor.
  void refreshOfficial()
    .then((r) => {
      if (r.written > 0) {
        console.log(
          `TÜİK TÜFE tazelendi: ${r.written} ay, en yeni ${r.newestMonth}`,
        );
      }
    })
    .catch((err) => {
      // Başarısızlık ölümcül değil: uygulama resmî seri olmadan da çalışıyor.
      console.warn(`TÜİK TÜFE tazelenemedi: ${err}`);
    });

  // Referans fiyatların günlük anlık görüntüsü.
  //
  // Kaynak yalnızca BUGÜNKÜ fiyatı yayımlıyor, geçmiş sorulamıyor —
  // toplanmayan günün verisi kalıcı olarak kayıp. TÜİK'ten farkı bu:
  // orada gecikmenin bedeli yok, burada var.
  //
  // Aile başına günlük tutuluyor, tek bir "bugün çekildi" bayrağı değil.
  // Sebebi Render ücretsiz katmanı: çekim iki buçuk dakika sürüyor ve
  // servis ortada uyuyabiliyor. Bir sonraki uyanış kalanları alıyor,
  // yapılmışları yeniden denemiyor.
  //
  // Bir seferde en fazla 40 aile: uyanışın tamamını buna ayırmıyoruz ve
  // kaynağa tek seferde 162 istek atmıyoruz. Gün içindeki uyanışlar
  // kalanı tamamlıyor.
  if (env.referenceFetch) {
    void refreshReference({ limit: 40 })
      .then((r) => {
        if (r.denenen > 0) {
          console.log(
            `Referans fiyat: ${r.denenen} aile denendi, ${r.yazilan} fiyat, ${r.kalan} aile kaldı`,
          );
        }
      })
      .catch((err) => {
        // Ölümcül değil: referans yoksa boy sorusu eskisi gibi kullanıcıya
        // gidiyor, uygulama çalışmaya devam ediyor.
        console.warn(`Referans fiyat çekilemedi: ${err}`);
      });
  }
});
