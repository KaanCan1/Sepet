/// Türkçe sayı biçimlendirme. intl locale verisi yüklemeye gerek kalmasın diye
/// elle yazıldı — uygulamada tek bir yerel var.
abstract final class Fmt {
  static String _group(String intPart) {
    final b = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) b.write('.');
      b.write(intPart[i]);
    }
    return b.toString();
  }

  /// 1917.45 -> "1.917,45"
  static String money(double v) {
    final s = v.abs().toStringAsFixed(2).split('.');
    final out = '${_group(s[0])},${s[1]}';
    return v < 0 ? '−$out' : out;
  }

  /// Miktar: gereksiz sıfır yazmadan, en fazla üç ondalık.
  /// 3 -> "3", 1.24 -> "1,240" (kilogramlı satırlar fişte böyle basılıyor)
  static String quantity(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceFirst('.', ',');
  }

  /// 47.2 -> "47,2"
  static String dec1(double v) =>
      v.abs().toStringAsFixed(1).replaceFirst('.', ',');

  /// 47.2 -> "47,2%"
  static String pct1(double v) => '${dec1(v)}%';

  /// 18.4 -> "+18,4%" · -6.2 -> "−6,2%"
  static String signedPct1(double v) => '${v < 0 ? '−' : '+'}${dec1(v)}%';

  /// 57 -> "+57%"
  static String signedPct0(double v) =>
      '${v < 0 ? '−' : '+'}${v.abs().round()}%';

  static const _monthsShort = [
    'OCA',
    'ŞUB',
    'MAR',
    'NİS',
    'MAY',
    'HAZ',
    'TEM',
    'AĞU',
    'EYL',
    'EKİ',
    'KAS',
    'ARA',
  ];
  static const _monthsLong = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// 18 AĞU
  static String dayMonth(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

  static String monthShort(DateTime d) => _monthsShort[d.month - 1];
  static String monthLong(DateTime d) => _monthsLong[d.month - 1];
}

/// Paket boyu etiketleri. Katalogdaki biçimle aynı yazılmak zorunda:
/// "400 g", "1,5 kg", "500 mL", "30'lu".
abstract final class SizeLabel {
  /// Adet ekinin ünlü uyumu, sayının okunuşundaki son ünlüye göre.
  ///
  /// 6 "altı" -> 6'lı, 8 "sekiz" -> 8'li, 3 "üç" -> 3'lü, 30 "otuz" -> 30'lu.
  /// Tam sayı adını üretmeye gerek yok: son basamak (ya da onluk) belirliyor.
  static const _ones = [
    "'lu",
    "'li",
    "'li",
    "'lü",
    "'lü",
    "'li",
    "'lı",
    "'li",
    "'li",
    "'lu",
  ];
  static const _tens = [
    "",
    "'lu",
    "'li",
    "'lu",
    "'lı",
    "'li",
    "'lı",
    "'li",
    "'li",
    "'lı",
  ];

  static String countSuffix(int n) {
    if (n <= 0) return "'li";
    if (n % 100 == 0 && n >= 100) return "'lü"; // yüz
    final last = n % 10;
    if (last != 0) return _ones[last];
    final tens = (n ~/ 10) % 10;
    return _tens[tens].isEmpty ? "'lu" : _tens[tens];
  }

  /// Kullanıcının girdiği sayı ve birimden etiket üretir.
  static String build(double value, String unit) {
    final n = value == value.roundToDouble() ? value.toInt() : null;
    // Fmt.quantity üç haneye tamamlıyor ("1,500"); etiketin kısası doğrusu.
    final text = n != null
        ? '$n'
        : value
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
              .replaceFirst('.', ',');
    if (unit == 'adet') return '$text${countSuffix(n ?? 1)}';
    return '$text $unit';
  }

  /// Etiketin kanonik birim cinsinden değeri: 400 g -> 0,4 (kilogram).
  static double toCanonical(double value, String unit) => switch (unit) {
    'g' => value / 1000,
    'mL' => value / 1000,
    _ => value,
  };

  /// Bir birimin hangi kanonik boyutta ölçtüğü: g ve kg -> kilogram.
  static String dimensionOf(String unit) => switch (unit) {
    'g' || 'kg' => 'kilogram',
    'mL' || 'litre' => 'litre',
    _ => 'adet',
  };

  /// Kullanıcıya sunulacak birimler — hepsi, grubun kendi boyutu başta.
  ///
  /// Liste eskiden grubun boyutuyla sınırlıydı ve bu bir çıkmaz üretiyordu:
  /// fişte "TACIROGLU SUT" yazan kalem aslında kaşar peyniriyse kullanıcının
  /// gireceği boy 400 g, ama ekran yalnızca mL ve litre öneriyordu. Yazan
  /// şey ile satın alınan şey her zaman aynı değil; birimi kısıtlamak
  /// kullanıcıyı bildiği doğruyu giremez hâle getiriyordu.
  ///
  /// Sıra önemli: grubun kendi boyutu başta durunca yaygın hâl tek
  /// dokunuşta kalıyor, boyut değiştirmek ise bilinçli bir seçim oluyor.
  static List<String> unitsFor(String canonicalUnit) => switch (canonicalUnit) {
    'kilogram' => const ['g', 'kg', 'mL', 'litre', 'adet'],
    'litre' => const ['mL', 'litre', 'g', 'kg', 'adet'],
    _ => const ['adet', 'g', 'kg', 'mL', 'litre'],
  };

  /// Kanonik birimin kısa adı — birim fiyat etiketinde geçen sözcük.
  static String shortUnit(String? canonicalUnit) => switch (canonicalUnit) {
    'kilogram' => 'kg',
    'litre' => 'litre',
    _ => 'adet',
  };
}
