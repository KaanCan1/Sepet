import Flutter
import UIKit
import Vision

/// Cihaz üstünde metin tanıma — Apple Vision.
///
/// ML Kit yerine Vision: iOS'a gömülü olduğu için ek pod yok, Apple Silicon
/// simülatöründe de çalışıyor (ML Kit'in ikili çerçeveleri arm64 simülatör
/// dilimi taşımıyor) ve Latin alfabesinde daha isabetli.
enum OcrPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "sepet/ocr",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize",
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      recognize(path: path, result: result)
    }
  }

  private static func recognize(path: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      result(FlutterError(code: "read_failed", message: "Görüntü açılamadı", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error {
        result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        return
      }
      let observations = request.results as? [VNRecognizedTextObservation] ?? []
      result(assemble(observations))
    }
    request.recognitionLevel = .accurate
    // Fiş metni doğal dil değil; düzeltme "SUT"u "SUÇ" yapıyor.
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["tr-TR", "en-US"]

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(image), options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// Vision parçaları ayrı ayrı döndürüyor: ürün adı bir gözlem, tutar başka
  /// bir gözlem. Ayrıştırıcı "AD ... TUTAR" biçimini tek satırda beklediği için
  /// dikey olarak örtüşenler birleştirilip soldan sağa diziliyor.
  private static func assemble(_ observations: [VNRecognizedTextObservation]) -> String {
    struct Piece {
      let text: String
      let minX: CGFloat
      let midY: CGFloat
      let height: CGFloat
    }

    let pieces: [Piece] = observations.compactMap { obs in
      guard let candidate = obs.topCandidates(1).first else { return nil }
      let box = obs.boundingBox
      return Piece(
        text: candidate.string,
        minX: box.minX,
        midY: box.midY,
        height: box.height
      )
    }
    guard !pieces.isEmpty else { return "" }

    // Vision'ın koordinatları sol-alt kökenli: büyük y yukarıda.
    let sorted = pieces.sorted { $0.midY > $1.midY }

    var rows: [[Piece]] = []
    for piece in sorted {
      // Aynı satır sayılması için dikey merkezler satır yüksekliğinin yarısı
      // kadar yakın olmalı.
      let tolerance = max(piece.height * 0.6, 0.006)
      if var last = rows.last, let ref = last.first, abs(ref.midY - piece.midY) <= tolerance {
        last.append(piece)
        rows[rows.count - 1] = last
      } else {
        rows.append([piece])
      }
    }

    return rows
      .map { row in
        row.sorted { $0.minX < $1.minX }
          .map(\.text)
          .joined(separator: "  ")
      }
      .joined(separator: "\n")
  }

  private static func cgOrientation(_ image: UIImage) -> CGImagePropertyOrientation {
    switch image.imageOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
