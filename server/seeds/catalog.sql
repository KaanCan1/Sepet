-- Referans katalog. Kullanıcıdan bağımsız, herkes paylaşıyor.
-- Tekrar çalıştırılabilir olsun diye hepsi ON CONFLICT DO NOTHING.
--
-- Üç kavram ayrı: ürün grubu (ne olduğu), marka (kimin ürettiği),
-- kanonik ürün (grup + marka + paket boyu). Endeks kanonik ürün
-- düzeyinde çalışıyor — 1,5 kg Sütaş yoğurt ile 1,5 kg Eker yoğurt
-- ayrı kalemler, çünkü fiyatları da ayrı seyrediyor.

INSERT INTO categories (code, name) VALUES
  ('01.1.1', 'Ekmek ve tahıllar'),
  ('01.1.2', 'Et'),
  ('01.1.4', 'Süt, peynir, yumurta'),
  ('01.1.5', 'Katı ve sıvı yağlar'),
  ('01.1.6', 'Meyve'),
  ('01.1.7', 'Sebze'),
  ('01.1.8', 'Şeker ve tatlı'),
  ('01.2.1', 'Kahve, çay, kakao'),
  ('01.2.2', 'Maden suyu ve meşrubat'),
  ('05.6.1', 'Temizlik ve ev sarf'),
  ('12.1.3', 'Kişisel bakım')
ON CONFLICT (code) DO NOTHING;

INSERT INTO merchants (name, chain_code) VALUES
  ('BİM', 'BIM'),
  ('A101', 'A101'),
  ('Şok', 'SOK'),
  ('Migros', 'MIGROS'),
  ('CarrefourSA', 'CARREFOURSA')
ON CONFLICT (chain_code) DO NOTHING;

-- ── Markalar ───────────────────────────────────────────────────────────────
-- normalized_name fişten okunan metinle eşleşmek için; normalize_raw_text
-- büyük harfe çevirip Türkçe harfleri ASCII'ye indiriyor, yani fişteki
-- "SUTAS" da "SÜTAŞ" da aynı yere düşüyor.
INSERT INTO brands (name, normalized_name)
SELECT b.name, trim(normalize_raw_text(b.name))
  FROM (VALUES
    ('Sütaş'), ('Pınar'), ('İçim'), ('Torku'), ('Eker'), ('Sek'),
    ('Tahsildaroğlu'), ('Muratbey'),
    ('Yudum'), ('Orkide'), ('Bizim'), ('Komili'), ('Kristal'),
    ('Filiz'), ('Nuhun Ankara'), ('Barilla'), ('Piyale'),
    ('Çaykur'), ('Doğuş'), ('Lipton'), ('Ofçay'),
    ('Nescafe'), ('Jacobs'), ('Kurukahveci Mehmet Efendi'),
    ('Banvit'), ('Şenpiliç'), ('Beypiliç'), ('Pınar Et'),
    ('Uno'), ('Sinangil'), ('Söke'), ('Duru'), ('Reis'), ('Yayla'),
    ('Balküpü'), ('Torku Şeker'),
    ('Omo'), ('Ariel'), ('Persil'), ('Fairy'), ('Domestos'),
    ('Elidor'), ('Colgate'), ('Signal'), ('Selpak'), ('Solo'),
    ('Erikli'), ('Sırma'), ('Coca-Cola'), ('Fanta'),
    ('Ülker'), ('Eti'), ('Sarelle'), ('Tamek'), ('Tat')
  ) AS b (name)
ON CONFLICT (normalized_name) DO NOTHING;

-- ── Ürün grupları ──────────────────────────────────────────────────────────
-- Kanonik birim burada: bir grubun tek birimi olur, yoksa aynı grupta
-- litre ile kilogram karışır ve birim fiyat karşılaştırması anlamını yitirir.
INSERT INTO product_groups (name, unit, category_id)
SELECT g.name, g.unit::product_unit, c.id
  FROM (VALUES
    ('Süt, tam yağlı',      'litre',    '01.1.4'),
    ('Süt, yarım yağlı',    'litre',    '01.1.4'),
    ('Yoğurt',              'kilogram', '01.1.4'),
    ('Ayran',               'litre',    '01.1.4'),
    ('Beyaz peynir',        'kilogram', '01.1.4'),
    ('Kaşar peyniri',       'kilogram', '01.1.4'),
    ('Yumurta',             'adet',     '01.1.4'),
    ('Tereyağı',            'kilogram', '01.1.5'),
    ('Ayçiçek yağı',        'litre',    '01.1.5'),
    ('Zeytinyağı',          'litre',    '01.1.5'),
    ('Ekmek, tam buğday',   'kilogram', '01.1.1'),
    ('Makarna, burgu',      'kilogram', '01.1.1'),
    ('Pirinç, baldo',       'kilogram', '01.1.1'),
    ('Un, buğday',          'kilogram', '01.1.1'),
    ('Bulgur, pilavlık',    'kilogram', '01.1.1'),
    ('Mercimek, kırmızı',   'kilogram', '01.1.1'),
    ('Nohut',               'kilogram', '01.1.1'),
    ('Tavuk göğsü',         'kilogram', '01.1.2'),
    ('Kıyma, dana',         'kilogram', '01.1.2'),
    ('Domates',             'kilogram', '01.1.7'),
    ('Salatalık',           'kilogram', '01.1.7'),
    ('Soğan, kuru',         'kilogram', '01.1.7'),
    ('Patates',             'kilogram', '01.1.7'),
    ('Biber, sivri',        'kilogram', '01.1.7'),
    ('Elma',                'kilogram', '01.1.6'),
    ('Muz',                 'kilogram', '01.1.6'),
    ('Portakal',            'kilogram', '01.1.6'),
    ('Çay, siyah',          'kilogram', '01.2.1'),
    ('Kahve, filtre',       'kilogram', '01.2.1'),
    ('Türk kahvesi',        'kilogram', '01.2.1'),
    ('Şeker, toz',          'kilogram', '01.1.8'),
    ('Fındık kreması',      'kilogram', '01.1.8'),
    ('Salça, domates',      'kilogram', '01.1.7'),
    ('Su, doğal kaynak',    'litre',    '01.2.2'),
    ('Gazlı içecek, kola',  'litre',    '01.2.2'),
    ('Deterjan, çamaşır',   'litre',    '05.6.1'),
    ('Bulaşık deterjanı',   'litre',    '05.6.1'),
    ('Çamaşır suyu',        'litre',    '05.6.1'),
    ('Kağıt havlu',         'adet',     '05.6.1'),
    ('Tuvalet kağıdı',      'adet',     '05.6.1'),
    ('Şampuan',             'litre',    '12.1.3'),
    ('Diş macunu',          'kilogram', '12.1.3')
  ) AS g (name, unit, cat_code)
  JOIN categories c ON c.code = g.cat_code
ON CONFLICT (name) DO NOTHING;

-- ── Kanonik ürünler ────────────────────────────────────────────────────────
-- size_value: paket içeriği grubun KANONİK BİRİMİ cinsinden.
-- Endeks birim fiyatı karşılaştırır; 30'lu yumurtanın adet fiyatı 15'linin
-- adet fiyatıyla kıyaslanabilsin diye burası doğru olmak zorunda.
--
-- brand NULL = markasız: açık sebze, meyve, fırın ekmeği. Kasada tartılan
-- ürünün markası yok, uydurmuyoruz.
-- Katalogun ürün listesi önce geçici bir tabloya yazılıyor: hem ekleme hem
-- de dosyanın sonundaki artık temizliği aynı listeye bakmak zorunda, yoksa
-- temizlik "markalı ürünü olan grupta markasız satır olmaz" gibi kaba bir
-- sezgiye dayanır ve meşru satırları da siler. Kıyma tam böyle bir ürün:
-- hem kasada tartılan markasız kilogram, hem Pınar Et 500 g.
DROP TABLE IF EXISTS katalog_urun;
CREATE TEMP TABLE katalog_urun (
  group_name text,
  brand_name text,
  size_label text,
  size_value numeric
);

INSERT INTO katalog_urun (group_name, brand_name, size_label, size_value)
VALUES
    -- grup                 marka                 boy etiketi   boy (kanonik birim)
    ('Süt, tam yağlı',      'Sütaş',              '1 litre',      1.0),
    ('Süt, tam yağlı',      'Pınar',              '1 litre',      1.0),
    ('Süt, tam yağlı',      'İçim',               '1 litre',      1.0),
    ('Süt, tam yağlı',      'Torku',              '1 litre',      1.0),
    ('Süt, tam yağlı',      'Sütaş',              '500 mL',       0.5),
    ('Süt, yarım yağlı',    'Pınar',              '1 litre',      1.0),
    ('Süt, yarım yağlı',    'İçim',               '1 litre',      1.0),

    ('Yoğurt',              'Sütaş',              '1 kg',         1.0),
    ('Yoğurt',              'Sütaş',              '1,5 kg',       1.5),
    ('Yoğurt',              'Eker',               '1,5 kg',       1.5),
    ('Yoğurt',              'Pınar',              '1,5 kg',       1.5),
    ('Yoğurt',              'Torku',              '1 kg',         1.0),

    ('Ayran',               'Sütaş',              '1 litre',      1.0),
    ('Ayran',               'Eker',               '1 litre',      1.0),

    ('Beyaz peynir',        'Sütaş',              '600 g',        0.6),
    ('Beyaz peynir',        'Pınar',              '600 g',        0.6),
    ('Beyaz peynir',        'Tahsildaroğlu',      '600 g',        0.6),
    ('Beyaz peynir',        'Sek',                '1 kg',         1.0),
    ('Kaşar peyniri',       'Muratbey',           '350 g',        0.35),
    ('Kaşar peyniri',       'Pınar',              '350 g',        0.35),

    ('Yumurta',             NULL,                 '30''lu',      30.0),
    ('Yumurta',             NULL,                 '15''li',      15.0),
    ('Yumurta',             NULL,                 '10''lu',      10.0),

    ('Tereyağı',            'Sütaş',              '250 g',        0.25),
    ('Tereyağı',            'İçim',               '250 g',        0.25),

    ('Ayçiçek yağı',        'Yudum',              '5 litre',      5.0),
    ('Ayçiçek yağı',        'Orkide',             '5 litre',      5.0),
    ('Ayçiçek yağı',        'Bizim',              '5 litre',      5.0),
    ('Ayçiçek yağı',        'Yudum',              '1 litre',      1.0),
    ('Zeytinyağı',          'Komili',             '1 litre',      1.0),
    ('Zeytinyağı',          'Kristal',            '1 litre',      1.0),

    ('Ekmek, tam buğday',   NULL,                 '500 g',        0.5),
    ('Makarna, burgu',      'Filiz',              '500 g',        0.5),
    ('Makarna, burgu',      'Nuhun Ankara',       '500 g',        0.5),
    ('Makarna, burgu',      'Barilla',            '500 g',        0.5),
    ('Pirinç, baldo',       'Reis',               '1 kg',         1.0),
    ('Pirinç, baldo',       'Duru',               '1 kg',         1.0),
    ('Un, buğday',          'Sinangil',           '2 kg',         2.0),
    ('Un, buğday',          'Söke',               '2 kg',         2.0),
    ('Bulgur, pilavlık',    'Duru',               '1 kg',         1.0),
    ('Bulgur, pilavlık',    'Reis',               '1 kg',         1.0),
    ('Mercimek, kırmızı',   'Yayla',              '1 kg',         1.0),
    ('Nohut',               'Yayla',              '1 kg',         1.0),

    ('Tavuk göğsü',         'Banvit',             'kilogram',     1.0),
    ('Tavuk göğsü',         'Şenpiliç',           'kilogram',     1.0),
    ('Tavuk göğsü',         'Beypiliç',           'kilogram',     1.0),
    ('Kıyma, dana',         NULL,                 'kilogram',     1.0),
    ('Kıyma, dana',         'Pınar Et',           '500 g',        0.5),

    ('Domates',             NULL,                 'kilogram',     1.0),
    ('Salatalık',           NULL,                 'kilogram',     1.0),
    ('Soğan, kuru',         NULL,                 'kilogram',     1.0),
    ('Patates',             NULL,                 'kilogram',     1.0),
    ('Biber, sivri',        NULL,                 'kilogram',     1.0),
    ('Elma',                NULL,                 'kilogram',     1.0),
    ('Muz',                 NULL,                 'kilogram',     1.0),
    ('Portakal',            NULL,                 'kilogram',     1.0),

    ('Çay, siyah',          'Çaykur',             '1 kg',         1.0),
    ('Çay, siyah',          'Doğuş',              '1 kg',         1.0),
    ('Çay, siyah',          'Lipton',             '500 g',        0.5),
    ('Çay, siyah',          'Ofçay',              '1 kg',         1.0),
    ('Kahve, filtre',       'Jacobs',             '250 g',        0.25),
    ('Türk kahvesi',        'Kurukahveci Mehmet Efendi', '250 g', 0.25),
    ('Türk kahvesi',        'Nescafe',            '200 g',        0.2),

    ('Şeker, toz',          'Balküpü',            '1 kg',         1.0),
    ('Şeker, toz',          'Torku Şeker',        '1 kg',         1.0),
    ('Fındık kreması',      'Sarelle',            '350 g',        0.35),
    ('Fındık kreması',      'Ülker',              '350 g',        0.35),
    ('Salça, domates',      'Tat',                '700 g',        0.7),
    ('Salça, domates',      'Tamek',              '700 g',        0.7),

    ('Su, doğal kaynak',    'Erikli',             '5 litre',      5.0),
    ('Su, doğal kaynak',    'Sırma',              '5 litre',      5.0),
    ('Gazlı içecek, kola',  'Coca-Cola',          '2,5 litre',    2.5),
    ('Gazlı içecek, kola',  'Fanta',              '2,5 litre',    2.5),

    ('Deterjan, çamaşır',   'Omo',                '3 litre',      3.0),
    ('Deterjan, çamaşır',   'Ariel',              '3 litre',      3.0),
    ('Deterjan, çamaşır',   'Persil',             '3 litre',      3.0),
    ('Bulaşık deterjanı',   'Fairy',              '1,3 litre',    1.3),
    ('Çamaşır suyu',        'Domestos',           '750 mL',       0.75),
    ('Kağıt havlu',         'Selpak',             '8''li',        8.0),
    ('Kağıt havlu',         'Solo',               '8''li',        8.0),
    ('Tuvalet kağıdı',      'Selpak',             '16''lı',      16.0),

    ('Şampuan',             'Elidor',             '500 mL',       0.5),
    ('Diş macunu',          'Colgate',            '75 mL',        0.075),
    ('Diş macunu',          'Signal',             '75 mL',        0.075)
  ;

INSERT INTO canonical_products (group_id, brand_id, size_label, size_value)
SELECT g.id, b.id, p.size_label, p.size_value
  FROM katalog_urun p
  JOIN product_groups g ON g.name = p.group_name
  LEFT JOIN brands b ON b.name = p.brand_name
ON CONFLICT DO NOTHING;

INSERT INTO official_series (code, publisher, name, is_official) VALUES
  ('TUIK_TUFE',  'TÜİK', 'TÜFE',   true),
  ('ENAG_ETUFE', 'ENAG', 'E-TÜFE', false)
ON CONFLICT (code) DO NOTHING;

-- ── Marka öncesi artıklar ──────────────────────────────────────────────────
-- Marka modeline geçmeden önce kurulmuş bir veritabanında eski kanonik
-- ürünler markasız satırlara dönüştü (migration 008). Yukarıdaki markalı
-- katalog onların üstüne binince ikisi yan yana kalıyor ve eşleştirme
-- ekranında "Süt, tam yağlı 1 litre" ile "Sütaş Süt, tam yağlı 1 litre"
-- birlikte listeleniyor. Temiz kurulumda 84 ürün çıkarken yükseltilen bir
-- veritabanında 104 çıkıyordu.
--
-- Ölçüt kataloğun kendi listesi: bu dosyanın saymadığı markasız satır artık
-- demektir. Sezgiye ("markalı ürünü olan grupta markasız satır olmaz")
-- dayansaydı kıyma gibi meşru satırlar da silinirdi — kıyma hem kasada
-- tartılan markasız kilogram, hem Pınar Et 500 g olarak var.
--
-- Kapsam iki kez daraltılıyor.
--
-- Bir: katalog yalnızca KENDİ gruplarının içini temizliyor. Bu dosyada adı
-- geçmeyen bir gruba hiç dokunmuyor. Bugün kanonik ürün yaratan tek yer bu
-- dosya, ama yarın "kullanıcı katalogda olmayan ürünü eklesin" denirse o
-- satırlar sessizce silinmesin.
--
-- İki: gözlemi, fiş satırı ya da öğrenilmiş eşleşmesi olan hiçbir satıra
-- dokunulmuyor. Kullanıcının verisi katalog düzenlemesine kurban gitmez.
DELETE FROM canonical_products cp
 WHERE cp.brand_id IS NULL
   AND EXISTS (
         SELECT 1
           FROM katalog_urun k
           JOIN product_groups g ON g.name = k.group_name
          WHERE g.id = cp.group_id
       )
   AND NOT EXISTS (
         SELECT 1
           FROM katalog_urun k
           JOIN product_groups g ON g.name = k.group_name
          WHERE k.brand_name IS NULL
            AND g.id = cp.group_id
            AND k.size_value = cp.size_value
       )
   AND NOT EXISTS (
         SELECT 1 FROM price_observations o WHERE o.canonical_product_id = cp.id
       )
   AND NOT EXISTS (
         SELECT 1 FROM receipt_lines l WHERE l.canonical_product_id = cp.id
       )
   AND NOT EXISTS (
         SELECT 1 FROM product_aliases a WHERE a.canonical_product_id = cp.id
       );

-- Boş grup temizliği bilerek YOK. Silme yalnızca katalogun kendi grupları
-- içinde çalışıyor ve her katalog grubuna en az bir ürün yazılıyor, yani
-- bu silme hiçbir grubu boşaltamıyor. Koşulsuz bir "boş grupları sil" ise
-- başka bir yerde yeni açılmış bir grubu ürünü yazılmadan önce yakalardı.

DROP TABLE katalog_urun;
