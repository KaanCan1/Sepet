/// Aramada karşılaştırılacak metni sadeleştirir.
///
/// İKİ AYRI SORUN ÇÖZÜLÜYOR. İkisi de ölçülerek doğrulandı; Dart'ın
/// `toLowerCase()`'iyle karşılaştırması aşağıda.
///
/// ASIL OLAN ŞAPKALAR. Kimse arama kutusuna "yoğurt" yazmak için
/// klavyesini değiştirmiyor. Düz `toLowerCase` ile "yogurt" Yoğurt'u,
/// "sut" Süt'ü, "cay" Çay'ı, "kagit" Kâğıt'ı bulmuyor.
///
/// İKİNCİSİ 'I' HARFİ. Dart 'I' → 'i' veriyor, oysa Türkçe'de 'ı' olmalı.
/// Bu yüzden "IŞIK" ile "ışık" `toLowerCase` altında eşleşmiyor.
///
/// 'İ' İÇİN SORUN YOK: Dart 'İ' → tek karakterli 'i' veriyor, yani
/// "ISTANBUL" ile "İstanbul" düz `toLowerCase` ile de eşleşiyor. (İlk
/// yazışta buraya "birleştirici nokta kalıyor" diye yanlış bir gerekçe
/// yazılmıştı; ölçünce öyle olmadığı çıktı.)
///
/// Katlama yalnızca karşılaştırmada; ekranda gösterilen metin olduğu gibi
/// kalıyor.
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
