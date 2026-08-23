-- Up Migration

-- Marka öncesi dönemden kalan katalog satırlarını yeni modelle uzlaştırır.
--
-- 008, mevcut kanonik ürünleri markasız satırlar olarak taşıdı — doğru olan
-- buydu, o sırada markanın ne olduğu bilinmiyordu. Ama yeni katalog aynı
-- ürünleri markalı hâlde getirince ikisi yan yana kaldı: temiz kurulumda
-- 84 ürün çıkarken, yükseltilen bir veritabanında 104 çıkıyor ve eşleştirme
-- ekranında "Süt, tam yağlı 1 litre" ile "Sütaş Süt, tam yağlı 1 litre"
-- birlikte listeleniyor.
--
-- Burada yalnızca YENİDEN ADLANDIRMA var. Migration'lar katalog yüklemesinden
-- ÖNCE koşuyor ve yeniden adlandırmanın yeri tam olarak burası: yeni katalog
-- grubu adıyla arayınca mevcut olanı buluyor, ikizini yaratmıyor.
--
-- Artık markasız satırların temizliği ise katalog yüklendikten SONRA olmak
-- zorunda — migration anında markalı satırlar henüz yok, "markalı karşılığı
-- var mı" koşulu hiç tutmazdı. O iş seeds/catalog.sql'in sonunda.

-- 1) Eski jenerik grup adlarını yeni kanonik adlara çek. Aksi hâlde
--    "Soğan" ve "Soğan, kuru" ayrı iki grup olarak birikirdi.
--
--    Hedef ad zaten varsa dokunma: o durumda çakışma olur ve zaten
--    birleştirilecek bir şey yok demektir.
UPDATE product_groups g
   SET name = v.yeni
  FROM (VALUES
    ('Soğan',             'Soğan, kuru'),
    ('Makarna',           'Makarna, burgu'),
    ('Un',                'Un, buğday'),
    ('Bulgur',            'Bulgur, pilavlık')
  ) AS v (eski, yeni)
 WHERE g.name = v.eski
   AND NOT EXISTS (SELECT 1 FROM product_groups x WHERE x.name = v.yeni);

-- Down Migration

-- Geri alınacak bir şey yok: bu migration şema değil veri düzeltiyor ve
-- yaptığı tek şey birkaç grubu yeniden adlandırmak. Eski adlara döndürmek
-- kataloğu tekrar ikizlerdi, yani geri alma iyileştirme değil bozma olurdu.
SELECT 1;
