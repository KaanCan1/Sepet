-- Up Migration

-- Referans çekiminin günlüğü: hangi gün, hangi aile, ne sonuç verdi.
--
-- İki iş görüyor.
--
-- BİRİNCİSİ, YARIM KALAN ÇEKİMİ SÜRDÜRMEK. Çekim 162 aile için 162 istek
-- demek, yaklaşık iki buçuk dakika. Render ücretsiz katmanda servis bu
-- sürenin ortasında uyuyabiliyor. Günlük olmasaydı tek bir "bugün çekildi mi"
-- bayrağı kalırdı ve yarıda kesilen gün bir daha tamamlanmazdı — toplanmayan
-- günün verisi de kalıcı olarak kayıp, çünkü kaynak yalnızca BUGÜNKÜ fiyatı
-- yayımlıyor.
--
-- İKİNCİSİ, KAYNAĞI YORMAMAK. Karşılığı olmayan aileler (Arko, Banvit —
-- kaynakta gerçekten yoklar) her açılışta yeniden denenirse kamuya açık bir
-- hizmete boşuna yük bineriz. Sonucu 'sonuc-yok' olarak yazmak, o aileyi o
-- gün için kapatıyor.
--
-- Sebep de saklanıyor çünkü "kaynakta sonuç yok" ile "boy tutmadı" bambaşka
-- iki problem: birincisi kataloğun kaynakta karşılığı olmaması, ikincisi
-- bizim boy okuyucumuzun eksiği. Zaman içinde hangisinin arttığını görmek,
-- hangi işi yapacağımızı söylüyor.
CREATE TABLE reference_fetch_log (
  fetched_on date        NOT NULL,
  -- Marka + grup, çekimdeki arama birimi: "Sütaş Yoğurt".
  family     text        NOT NULL,
  outcome    text        NOT NULL,
  written    integer     NOT NULL DEFAULT 0,
  at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (fetched_on, family)
);

-- Down Migration

DROP TABLE IF EXISTS reference_fetch_log;
