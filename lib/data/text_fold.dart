/// Aramada karşılaştırılacak metni sadeleştirir.
///
/// İKİ AYRI SORUN ÇÖZÜLÜYOR.
///
/// Biri Dart'ın `toLowerCase()`'inin Türkçe bilmemesi: 'I' → 'i' veriyor
/// (oysa 'ı' olmalı) ve 'İ' → 'i' + ayrı bir birleştirici nokta veriyor,
/// yani dizginin uzunluğu bile değişiyor. Kullanıcı "ISTANBUL" yazınca
/// "İstanbul" bulunamıyordu.
///
/// Diğeri şapka ve noktalar: kimse arama kutusuna "yoğurt" yazmak için
/// klavyesini değiştirmiyor. "yogurt" da "çay" yerine "cay" da bulmalı.
/// Bu yüzden fark gözetmeyen bir tabana indiriliyor — sonuç ekranda
/// gösterilmiyor, yalnızca karşılaştırmada kullanılıyor.
library;

/// Türkçe büyük harflerin DOĞRU küçük karşılıkları. Dart bunları bilmiyor.
const _kucuk = {
  'I': 'ı',
  'İ': 'i',
  'Ş': 'ş',
  'Ğ': 'ğ',
  'Ü': 'ü',
  'Ö': 'ö',
  'Ç': 'ç',
};

/// Aramada fark gözetilmeyen harfler. Şapkalılar da burada: fişte "kâğıt"
/// yazıyor, kullanıcı "kagit" yazıyor.
const _sade = {
  'ı': 'i',
  'ş': 's',
  'ğ': 'g',
  'ü': 'u',
  'ö': 'o',
  'ç': 'c',
  'â': 'a',
  'î': 'i',
  'û': 'u',
};

String searchFold(String s) {
  final out = StringBuffer();
  for (final ch in s.split('')) {
    // Önce doğru küçültme, sonra sadeleştirme. Sıra önemli: 'İ' önce 'i'
    // olmalı ki sadeleştirme tablosuna düşmesin ve nokta kaybolmasın.
    final kucuk = _kucuk[ch] ?? ch.toLowerCase();
    out.write(_sade[kucuk] ?? kucuk);
  }
  return out.toString();
}
