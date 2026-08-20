-- Referans katalog. Kullanıcıdan bağımsız, herkes paylaşıyor.
-- Tekrar çalıştırılabilir olsun diye hepsi ON CONFLICT DO NOTHING.

INSERT INTO categories (code, name) VALUES
  ('01.1.1', 'Ekmek ve tahıllar'),
  ('01.1.2', 'Et'),
  ('01.1.4', 'Süt, peynir, yumurta'),
  ('01.1.5', 'Katı ve sıvı yağlar'),
  ('01.1.6', 'Meyve'),
  ('01.1.7', 'Sebze'),
  ('01.1.8', 'Şeker ve tatlı'),
  ('01.2.1', 'Kahve, çay, kakao'),
  ('05.6.1', 'Temizlik ve ev sarf')
ON CONFLICT (code) DO NOTHING;

INSERT INTO merchants (name, chain_code) VALUES
  ('BİM', 'BIM'),
  ('A101', 'A101'),
  ('Şok', 'SOK'),
  ('Migros', 'MIGROS'),
  ('CarrefourSA', 'CARREFOURSA')
ON CONFLICT (chain_code) DO NOTHING;

-- size_value: paket içeriği KANONİK BİRİM cinsinden.
-- Endeks birim fiyatı karşılaştırır; 30'lu yumurtanın adet fiyatı 15'linin
-- adet fiyatıyla kıyaslanabilsin diye burası doğru olmak zorunda.
INSERT INTO canonical_products (name, size_label, unit, size_value, category_id)
SELECT p.name, p.size_label, p.unit::product_unit, p.size_value, c.id
  FROM (VALUES
    ('Süt, tam yağlı',      '1 litre',   'litre',     1.0,   '01.1.4'),
    ('Süt, yarım yağlı',    '1 litre',   'litre',     1.0,   '01.1.4'),
    ('Yumurta',             '30''lu',    'adet',     30.0,   '01.1.4'),
    ('Yumurta',             '15''li',    'adet',     15.0,   '01.1.4'),
    ('Yumurta',             '10''lu',    'adet',     10.0,   '01.1.4'),
    ('Beyaz peynir',        '600 g',     'kilogram',  0.6,   '01.1.4'),
    ('Kaşar peyniri',       '350 g',     'kilogram',  0.35,  '01.1.4'),
    ('Yoğurt',              '1 kg',      'kilogram',  1.0,   '01.1.4'),
    ('Tereyağı',            '250 g',     'kilogram',  0.25,  '01.1.5'),
    ('Ayçiçek yağı',        '5 litre',   'litre',     5.0,   '01.1.5'),
    ('Ayçiçek yağı',        '1 litre',   'litre',     1.0,   '01.1.5'),
    ('Zeytinyağı',          '1 litre',   'litre',     1.0,   '01.1.5'),
    ('Ekmek, tam buğday',   '500 g',     'kilogram',  0.5,   '01.1.1'),
    ('Makarna',             '500 g',     'kilogram',  0.5,   '01.1.1'),
    ('Pirinç, baldo',       '1 kg',      'kilogram',  1.0,   '01.1.1'),
    ('Un',                  '2 kg',      'kilogram',  2.0,   '01.1.1'),
    ('Bulgur',              '1 kg',      'kilogram',  1.0,   '01.1.1'),
    ('Mercimek, kırmızı',   '1 kg',      'kilogram',  1.0,   '01.1.1'),
    ('Tavuk göğsü',         'kilogram',  'kilogram',  1.0,   '01.1.2'),
    ('Kıyma, dana',         'kilogram',  'kilogram',  1.0,   '01.1.2'),
    ('Domates',             'kilogram',  'kilogram',  1.0,   '01.1.7'),
    ('Salatalık',           'kilogram',  'kilogram',  1.0,   '01.1.7'),
    ('Soğan',               'kilogram',  'kilogram',  1.0,   '01.1.7'),
    ('Patates',             'kilogram',  'kilogram',  1.0,   '01.1.7'),
    ('Elma',                'kilogram',  'kilogram',  1.0,   '01.1.6'),
    ('Muz',                 'kilogram',  'kilogram',  1.0,   '01.1.6'),
    ('Çay, siyah',          '1 kg',      'kilogram',  1.0,   '01.2.1'),
    ('Kahve, filtre',       '250 g',     'kilogram',  0.25,  '01.2.1'),
    ('Şeker, toz',          '1 kg',      'kilogram',  1.0,   '01.1.8'),
    ('Deterjan, çamaşır',   '3 litre',   'litre',     3.0,   '05.6.1')
  ) AS p (name, size_label, unit, size_value, cat_code)
  JOIN categories c ON c.code = p.cat_code
ON CONFLICT (name, size_label) DO NOTHING;

INSERT INTO official_series (code, publisher, name, is_official) VALUES
  ('TUIK_TUFE',  'TÜİK', 'TÜFE',   true),
  ('ENAG_ETUFE', 'ENAG', 'E-TÜFE', false)
ON CONFLICT (code) DO NOTHING;
