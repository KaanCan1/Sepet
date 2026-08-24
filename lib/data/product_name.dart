/// Fiş satırındaki kısaltılmış ürün adını okunur hâle getirir.
///
/// Yazarkasa ürün adını sabit bir kolona sığdırmak için kesiyor ve Türkçe
/// harfleri düşürüyor: "MIGROS T.YAGLI YOGU.", "UNTAD PREMIUM TAMBU",
/// "HASATA PILAVLIK B". Kullanıcı bunu ne fişte okuyabiliyor ne uygulamada.
///
/// Burada yapılan çeviri değil **açma**: yalnızca sözlükte karşılığı olan
/// belirteçler genişletiliyor, tanınmayan hiçbir şeye dokunulmuyor. Yanlış
/// tamamlanmış bir ad eksik addan daha kötü — kullanıcı onu düzeltmesi
/// gerektiğini fark etmez.
///
/// [ParsedLine.raw] bu işlemden etkilenmiyor. Sunucudaki alias tablosu ham
/// metinle anahtarlanıyor; oynarsak öğrenilmiş eşleşmeler kopar.
library;

abstract final class ProductName {
  /// Çok kelimeli kalıplar. Uzundan kısaya deneniyor ki "TAM YAGLI" varken
  /// "YAGLI" tek başına yakalanmasın.
  static const _phrases = <String, String>{
    'T YAGLI': 'tam yağlı',
    'TAM YAGLI': 'tam yağlı',
    'Y YAGLI': 'yarım yağlı',
    'YARIM YAGLI': 'yarım yağlı',
    'TAM BUGDAY': 'tam buğday',
    'PILAVLIK B': 'pilavlık bulgur',
    'PILAVLIK BUL': 'pilavlık bulgur',
    'KOFTELIK B': 'köftelik bulgur',
    'BEYAZ PEY': 'beyaz peynir',
    'KASAR PEY': 'kaşar peyniri',
    'AYCICEK Y': 'ayçiçek yağı',
    'DOMATES SAL': 'domates salçası',
    'KIRMIZI MER': 'kırmızı mercimek',
    'MADEN S': 'maden suyu',
    'MEYVE SUYU': 'meyve suyu',
  };

  /// Tek belirteç karşılıkları — kesilmiş ya da kısaltılmış hâller.
  static const _tokens = <String, String>{
    'YOGU': 'yoğurt',
    'YOG': 'yoğurt',
    'YOGRT': 'yoğurt',
    'YOGURT': 'yoğurt',
    'TAMBU': 'tam buğday',
    'TAMBUG': 'tam buğday',
    'BUGDAY': 'buğday',
    'CECIL': 'çeçil peyniri',
    'PEY': 'peynir',
    'PEYN': 'peynir',
    'SUT': 'süt',
    'AYC': 'ayçiçek',
    'AYCICEK': 'ayçiçek',
    'YAGLI': 'yağlı',
    'YAG': 'yağ',
    'EKM': 'ekmek',
    'MAK': 'makarna',
    'DET': 'deterjan',
    'DETER': 'deterjan',
    'TEMZ': 'temizlik',
    'POSET': 'poşet',
    'KAGIT': 'kağıt',
    'TUV': 'tuvalet',
    'SAL': 'salça',
    'MER': 'mercimek',
    'PILIC': 'piliç',
    'SOGAN': 'soğan',
    'CAY': 'çay',
    'SEK': 'şeker',
    'CIK': 'çikolata',
    'BISK': 'bisküvi',
  };

  /// Fişte Türkçe harfsiz basılan yaygın kelimeler. Sözlükte kısaltma
  /// karşılığı olmayan ama şapkası düşmüş belirteçler buradan doğruluyor.
  static const _diacritics = <String, String>{
    'BONFILE': 'bonfile',
    'BEYAZ': 'beyaz',
    'PEYNIR': 'peynir',
    'PEYNIRI': 'peyniri',
    'KASAR': 'kaşar',
    'BAR': 'bar',
    'MAKARNA': 'makarna',
    'BURGU': 'burgu',
    'CAMASIR': 'çamaşır',
    'BULASIK': 'bulaşık',
    'SAMPUAN': 'şampuan',
    'MACUNU': 'macunu',
    'TAVUK': 'tavuk',
    'GOGUS': 'göğüs',
    'GOGSU': 'göğsü',
    'KIYMA': 'kıyma',
    'DANA': 'dana',
    'HAVLU': 'havlu',
    'PLASTIK': 'plastik',
    'PREMIUM': 'premium',
    'EKSTRA': 'ekstra',
    'PROTEIN': 'protein',
    'TAM': 'tam',
    'PILAVLIK': 'pilavlık',
    'BULGUR': 'bulgur',
    'PIRINC': 'pirinç',
    'BALDO': 'baldo',
    'NOHUT': 'nohut',
    'ZEYTINYAGI': 'zeytinyağı',
    'TEREYAGI': 'tereyağı',
    'AYRAN': 'ayran',
    'YUMURTA': 'yumurta',
    'DOMATES': 'domates',
    'SALATALIK': 'salatalık',
    'PATATES': 'patates',
    'ELMA': 'elma',
    'PORTAKAL': 'portakal',
    'SIVRI': 'sivri',
    'BIBER': 'biber',
  };

  /// "6LI" -> "6'lı", "30LU" -> "30'lu".
  static final _countSuffix = RegExp(r'^(\d+)(LI|LU)$');

  /// Sözlük anahtarlarıyla aynı düzleme indirir.
  static String _flatten(String s) {
    const from = 'ıİğĞüÜşŞöÖçÇâÂîÎûÛ';
    const to = 'IIGGUUSSOOCCAAIIUU';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().toUpperCase();
  }

  /// Ham fiş satırından okunur ad üretir.
  ///
  /// Hiçbir belirteç tanınmazsa girdi olduğu gibi geri döner — uydurmuyor.
  static String expand(String raw) {
    // Nokta kısaltma işareti ("YOGU." , "T.YAGLI"); ayırıcı sayılıyor.
    final cleaned = raw
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return raw;

    var flat = _flatten(cleaned);

    final phrases = _phrases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in phrases) {
      final idx = flat.indexOf(phrase);
      if (idx < 0) continue;
      final before = flat.substring(0, idx);
      final after = flat.substring(idx + phrase.length);
      // Yalnızca kelime sınırında.
      if (before.isNotEmpty && !before.endsWith(' ')) continue;
      if (after.isNotEmpty && !after.startsWith(' ')) continue;
      flat = '$before${_phrases[phrase]}$after';
    }

    final out = <String>[];
    for (final token in flat.split(' ')) {
      if (token.isEmpty) continue;
      final count = _countSuffix.firstMatch(token);
      if (count != null) {
        final suffix = count.group(2) == 'LI' ? "'lı" : "'lu";
        out.add('${count.group(1)}$suffix');
        continue;
      }
      // Kalıp yerleştirmesinden gelen küçük harfli parçalara dokunulmuyor.
      out.add(_tokens[token] ?? _diacritics[token] ?? token);
    }

    final joined = out.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return joined.isEmpty ? raw : _titleCase(joined);
  }

  /// İlk harf büyük, gerisi olduğu gibi. Marka adları zaten büyük geliyor;
  /// onlara dokunulmuyor.
  static String _titleCase(String s) {
    final first = s.substring(0, 1);
    return '${first == 'i' ? 'İ' : first.toUpperCase()}${s.substring(1)}';
  }
}
