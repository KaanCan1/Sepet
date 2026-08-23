import { createApp } from './app.js';
import { env } from './env.js';
import { refreshOfficial } from './official/refresh.js';

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
        console.log(`TÜİK TÜFE tazelendi: ${r.written} ay, en yeni ${r.newestMonth}`);
      }
    })
    .catch((err) => {
      // Başarısızlık ölümcül değil: uygulama resmî seri olmadan da çalışıyor.
      console.warn(`TÜİK TÜFE tazelenemedi: ${err}`);
    });
});
