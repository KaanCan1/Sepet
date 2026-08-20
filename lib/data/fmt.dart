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
