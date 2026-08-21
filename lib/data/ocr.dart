import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'receipt_parser.dart';

/// Cihaz üstünde metin tanıma.
///
/// Fişin fotoğrafı cihazdan çıkmıyor: OCR burada çalışıyor, sunucuya yalnızca
/// ayrıştırılmış satırlar gidiyor. Bu hem KVKK açısından veri minimizasyonu
/// hem de maliyet kararı — her fiş için bulut vision çağırmak kullanıcı başına
/// aylık maliyeti anlamsızlaştırırdı.
///
/// iOS tarafı Apple Vision kullanıyor (bkz. ios/Runner/OcrPlugin.swift).
/// Android karşılığı henüz yok; hedef şimdilik App Store.
class Ocr {
  const Ocr();

  static const _channel = MethodChannel('sepet/ocr');

  bool get isSupported => Platform.isIOS;

  Future<ParsedReceipt> readReceipt(String imagePath) async {
    if (!isSupported) {
      throw const OcrUnsupported();
    }
    final text = await _channel.invokeMethod<String>('recognize', {
      'path': imagePath,
    });
    // Ayrıştırıcı bir fiş biçiminde yanılırsa ham metni görmeden düzeltmek
    // mümkün değil; yalnızca hata ayıklama derlemesinde basılıyor.
    if (kDebugMode) {
      debugPrint('--- OCR ---\n${text ?? ''}\n--- OCR SONU ---');
    }
    return ReceiptParser.parse(text ?? '');
  }
}

class OcrUnsupported implements Exception {
  const OcrUnsupported();

  @override
  String toString() => 'Fiş okuma şimdilik yalnızca iPhone\'da çalışıyor.';
}
