import '../theme/tokens.dart';
import 'models.dart';

/// Demo verisi. Gerçek uygulamada bu katmanın yerini Node/Postgres backend'i
/// alacak; ekranlar aynı modelleri tükettiği için değişiklik burada kalır.
abstract final class Mock {
  static final now = DateTime(2026, 8, 20);

  // ── 01 Endeks ────────────────────────────────────────────────────────────
  static const headline = 47.2;
  static const monthDelta = 1.4;

  static const series = <Series>[
    Series(
      name: 'Senin sepetin',
      color: C.ink,
      value: 47.2,
      points: [
        28.1,
        30.4,
        33.0,
        35.2,
        36.1,
        38.5,
        39.9,
        41.2,
        43.0,
        44.6,
        45.8,
        47.2
      ],
    ),
    Series(
      name: 'TÜİK TÜFE',
      color: C.ref,
      value: 31.8,
      dashed: true,
      points: [
        22.0,
        23.4,
        24.9,
        25.8,
        26.4,
        27.2,
        28.0,
        28.7,
        29.5,
        30.4,
        31.1,
        31.8
      ],
    ),
    Series(
      name: 'ENAG E-TÜFE',
      color: C.grey,
      value: 50.5,
      points: [
        31.2,
        33.5,
        36.0,
        38.4,
        40.1,
        42.0,
        43.6,
        45.2,
        46.8,
        48.3,
        49.5,
        50.5
      ],
    ),
  ];

  static final receipts = <Receipt>[
    Receipt(
      id: 'r1',
      market: 'A101',
      city: 'Kırklareli',
      date: DateTime(2026, 8, 18),
      itemCount: 11,
      total: 842.60,
    ),
    Receipt(
      id: 'r2',
      market: 'Migros',
      city: null,
      date: DateTime(2026, 8, 14),
      itemCount: 23,
      total: 1917.45,
    ),
    Receipt(
      id: 'r3',
      market: 'BİM',
      city: 'Kırklareli',
      date: DateTime(2026, 8, 9),
      itemCount: 8,
      total: 496.20,
    ),
    Receipt(
      id: 'r4',
      market: 'Şok',
      city: null,
      date: DateTime(2026, 8, 2),
      itemCount: 14,
      total: 1104.90,
    ),
  ];

  // ── 02 Fiş okuma ─────────────────────────────────────────────────────────
  static const slipText = '''MIGROS TICARET A.S.
KIRKLARELI SUBE
------------------------
SUT TAM YAGLI 1L 3x
AYCICEK YAGI 5L
YUMURTA 30LU
BEYAZ PEYNIR 600G
DOMATES KG 1,240
EKMEK TAM BUGDAY
CAYKUR RIZE 1KG
------------------------
TOPLAM''';

  static const scanned = <ReceiptLine>[
    ReceiptLine(
      raw: 'SUT TAM YAGLI 1L',
      qtyLabel: 'x3',
      canonical: 'Süt, tam yağlı 1 L',
      amount: 116.70,
    ),
    ReceiptLine(
      raw: 'AYCICEK YAGI 5L',
      canonical: 'Ayçiçek yağı 5 L',
      amount: 389.90,
    ),
    ReceiptLine(
      raw: 'YUMURTA 30LU',
      canonical: "Yumurta, 30'lu",
      amount: 184.50,
      needsMatch: true,
      candidates: ["Yumurta, 30'lu", "Yumurta, 15'li", "Yumurta, 10'lu"],
    ),
    ReceiptLine(
      raw: 'DOMATES KG',
      qtyLabel: '1,240 kg',
      canonical: 'Domates',
      amount: 92.88,
      needsMatch: true,
      candidates: ['Domates', 'Domates, salkım', 'Domates, kokteyl'],
    ),
    ReceiptLine(
      raw: 'BEYAZ PEYNIR 600G',
      canonical: 'Beyaz peynir 600 g',
      amount: 219.90,
    ),
    ReceiptLine(
      raw: 'EKMEK TAM BUGDAY',
      canonical: 'Ekmek, tam buğday 500 g',
      amount: 32.00,
    ),
    ReceiptLine(
      raw: 'CAYKUR RIZE 1KG',
      canonical: 'Çay, siyah 1 kg',
      amount: 268.00,
    ),
  ];

  // ── 03 Ürün geçmişi ──────────────────────────────────────────────────────
  static final oil = Product(
    id: 'p1',
    name: 'Ayçiçek yağı',
    size: '5 litre',
    observations: 14,
    marketCount: 4,
    monthSpan: 11,
    history: [
      PricePoint(DateTime(2025, 9, 12), 248.00),
      PricePoint(DateTime(2025, 10, 4), 252.50),
      PricePoint(DateTime(2025, 11, 19), 266.30),
      PricePoint(DateTime(2025, 12, 7), 264.00),
      PricePoint(DateTime(2026, 1, 15), 293.80),
      PricePoint(DateTime(2026, 2, 26), 307.50),
      PricePoint(DateTime(2026, 4, 9), 335.00),
      PricePoint(DateTime(2026, 5, 21), 348.70),
      PricePoint(DateTime(2026, 7, 3), 380.70),
      PricePoint(DateTime(2026, 8, 14), 389.90),
    ],
    byMarket: [
      MarketPrice('BİM', 359.00),
      MarketPrice('A101', 372.50),
      MarketPrice('Migros', 389.90),
    ],
  );

  static final egg = Product(
    id: 'p2',
    name: 'Yumurta',
    size: "30'lu",
    observations: 9,
    marketCount: 3,
    monthSpan: 8,
    history: [
      PricePoint(DateTime(2025, 12, 3), 121.00),
      PricePoint(DateTime(2026, 1, 22), 128.50),
      PricePoint(DateTime(2026, 3, 11), 139.90),
      PricePoint(DateTime(2026, 4, 27), 148.00),
      PricePoint(DateTime(2026, 6, 6), 161.40),
      PricePoint(DateTime(2026, 7, 18), 172.90),
      PricePoint(DateTime(2026, 8, 14), 184.50),
    ],
    byMarket: [
      MarketPrice('Şok', 169.90),
      MarketPrice('A101', 178.00),
      MarketPrice('Migros', 184.50),
    ],
  );

  static final cheese = Product(
    id: 'p3',
    name: 'Beyaz peynir',
    size: '600 g',
    observations: 11,
    marketCount: 4,
    monthSpan: 10,
    history: [
      PricePoint(DateTime(2025, 10, 8), 142.50),
      PricePoint(DateTime(2025, 12, 14), 158.00),
      PricePoint(DateTime(2026, 2, 2), 171.90),
      PricePoint(DateTime(2026, 4, 16), 189.00),
      PricePoint(DateTime(2026, 6, 25), 204.50),
      PricePoint(DateTime(2026, 8, 14), 219.90),
    ],
    byMarket: [
      MarketPrice('BİM', 198.00),
      MarketPrice('Şok', 209.90),
      MarketPrice('Migros', 219.90),
    ],
  );

  static final tomato = Product(
    id: 'p4',
    name: 'Domates',
    size: '1 kilogram',
    observations: 16,
    marketCount: 4,
    monthSpan: 11,
    history: [
      PricePoint(DateTime(2025, 9, 12), 42.00),
      PricePoint(DateTime(2025, 11, 20), 58.50),
      PricePoint(DateTime(2026, 1, 9), 79.90),
      PricePoint(DateTime(2026, 3, 28), 88.00),
      PricePoint(DateTime(2026, 5, 30), 79.80),
      PricePoint(DateTime(2026, 8, 14), 74.90),
    ],
    byMarket: [
      MarketPrice('Migros', 74.90),
      MarketPrice('A101', 76.50),
      MarketPrice('BİM', 71.00),
    ],
  );

  static final products = <Product>[oil, egg, cheese, tomato];

  // ── 04 Aylık kart ────────────────────────────────────────────────────────
  static const receiptCount = 38;
  static const observationCount = 214;

  // ── Veri kaynakları ──────────────────────────────────────────────────────
  static final sources = <DataSource>[
    DataSource(
      name: 'TÜFE',
      publisher: 'TÜİK',
      official: true,
      value: 31.8,
      lastRelease: DateTime(2026, 8, 3),
      nextRelease: DateTime(2026, 9, 3),
    ),
    DataSource(
      name: 'E-TÜFE',
      publisher: 'ENAG',
      official: false,
      value: 50.5,
      lastRelease: DateTime(2026, 8, 3),
      nextRelease: DateTime(2026, 9, 3),
    ),
  ];

  static const movers = <Mover>[
    Mover("Yumurta, 30'lu", 18.4),
    Mover('Beyaz peynir 600 g', 11.0),
    Mover('Domates', -6.2),
  ];
}
