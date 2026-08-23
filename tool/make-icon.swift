// Uygulama simgesini üretir: kâğıt zemin üzerinde mürekkep bir sepet.
//
// Neden çizim, neden hazır PNG değil: simge her boyutta yeniden çiziliyor,
// yani 20 piksellik hâli 1024'ün ezilmiş kopyası değil, kendi ölçeğinde
// hesaplanmış geometrisi. İnce çizgiler küçük boyutta kaybolmuyor.
//
// Çalıştırmak için:  swift tool/make-icon.swift
import AppKit
import CoreGraphics
import Foundation

// Tasarım belirteçleriyle aynı renkler (lib/theme/tokens.dart).
let paper = CGColor(red: 0xF7 / 255, green: 0xF6 / 255, blue: 0xF3 / 255, alpha: 1)
let ink   = CGColor(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1A / 255, alpha: 1)

/// Geometri 1024'lük tuval için yazıldı, [s] ile ölçekleniyor.
func drawIcon(into ctx: CGContext, size: CGFloat) {
    let s = size / 1024

    // Çizim tuvalde küçük kalıyordu; iOS simgeleri kareyi daha çok doldurur.
    // z büyütme oranı, cy ise çizimin GÖRSEL dikey merkezi — sapın tepesi ile
    // gövdenin altının ortası, tuvalin merkezi değil. İkisi karıştırılırsa
    // sepet aşağı kaçmış görünüyor.
    let z: CGFloat = 1.14
    let cy: CGFloat = 536

    ctx.setFillColor(paper)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // CoreGraphics'in başlangıcı sol ALT; tasarım sol üstten ölçüldüğü için
    // y'yi çeviriyoruz. Aksi hâlde sepet baş aşağı çıkar.
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(
            x: (512 + (x - 512) * z) * s,
            y: size - (512 + (y - cy) * z) * s,
        )
    }

    /// Uzunlukları da aynı oranda büyütür (çizgi kalınlığı, köşe yarıçapı).
    func d(_ v: CGFloat) -> CGFloat { v * z * s }

    ctx.setFillColor(ink)
    ctx.setStrokeColor(ink)

    // ── Sap ────────────────────────────────────────────────────────────────
    // Yarım daire. Uçları yuvarlak, kalınlık küçük boyutta da görünsün diye
    // cömert.
    ctx.setLineWidth(d(58))
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.addArc(
        center: p(512, 430),
        radius: d(176),
        startAngle: 0,
        endAngle: .pi,
        clockwise: false,
    )
    ctx.strokePath()

    // ── Ağız ───────────────────────────────────────────────────────────────
    // Gövdeden biraz taşan bir bant: sepeti kovadan ayıran ayrıntı bu.
    // Yuvarlatılmış bant. Köşeleri p() ile kurulamadığı için iki köşe
    // noktasından dikdörtgen çıkarılıyor.
    let rimTopLeft = p(138, 424)
    let rimBotRight = p(886, 500)
    let rim = CGPath(
        roundedRect: CGRect(
            x: rimTopLeft.x, y: rimBotRight.y,
            width: rimBotRight.x - rimTopLeft.x,
            height: rimTopLeft.y - rimBotRight.y,
        ),
        cornerWidth: d(30), cornerHeight: d(30), transform: nil,
    )
    ctx.addPath(rim)
    ctx.fillPath()

    // ── Gövde ──────────────────────────────────────────────────────────────
    // Aşağı doğru daralan yamuk; alt köşeler yuvarlatılmış.
    let topY: CGFloat = 500, botY: CGFloat = 818
    let topL: CGFloat = 178, topR: CGFloat = 846
    let botL: CGFloat = 290, botR: CGFloat = 734
    let r: CGFloat = 46

    let body = CGMutablePath()
    body.move(to: p(topL, topY))
    body.addLine(to: p(topR, topY))
    body.addArc(tangent1End: p(botR, botY), tangent2End: p(botL, botY), radius: d(r))
    body.addArc(tangent1End: p(botL, botY), tangent2End: p(topL, topY), radius: d(r))
    body.closeSubpath()

    ctx.addPath(body)
    ctx.fillPath()

    // ── Çıtalar ────────────────────────────────────────────────────────────
    // Gövdeden kâğıt renginde oyuluyor. Yamuğun daralmasını takip ediyorlar,
    // dikey olsalardı sepet düz bir kutuya benzerdi.
    ctx.setFillColor(paper)
    let slatTopY: CGFloat = 548, slatBotY: CGFloat = 786
    for t in [0.2, 0.4, 0.6, 0.8] as [CGFloat] {
        let cxTop = topL + t * (topR - topL)
        let cxBot = botL + t * (botR - botL)
        let wTop: CGFloat = 25, wBot: CGFloat = 18

        let slat = CGMutablePath()
        slat.move(to: p(cxTop - wTop, slatTopY))
        slat.addLine(to: p(cxTop + wTop, slatTopY))
        slat.addLine(to: p(cxBot + wBot, slatBotY))
        slat.addLine(to: p(cxBot - wBot, slatBotY))
        slat.closeSubpath()
        ctx.addPath(slat)
        ctx.fillPath()
    }
}

func writePNG(size: Int, to url: URL) throws {
    let dim = CGFloat(size)
    guard
        let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            // App Store saydam simge kabul etmiyor: alfa yok.
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
        )
    else { throw NSError(domain: "ikon", code: 1) }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    drawIcon(into: ctx, size: dim)

    guard
        let image = ctx.makeImage(),
        let dest = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil,
        )
    else { throw NSError(domain: "ikon", code: 2) }

    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "ikon", code: 3)
    }
}

// Dosya adı -> kenar uzunluğu. Contents.json'daki adlarla birebir.
let targets: [(String, Int)] = [
    ("Icon-App-1024x1024@1x", 1024),
    ("Icon-App-20x20@1x", 20), ("Icon-App-20x20@2x", 40), ("Icon-App-20x20@3x", 60),
    ("Icon-App-29x29@1x", 29), ("Icon-App-29x29@2x", 58), ("Icon-App-29x29@3x", 87),
    ("Icon-App-40x40@1x", 40), ("Icon-App-40x40@2x", 80), ("Icon-App-40x40@3x", 120),
    ("Icon-App-60x60@2x", 120), ("Icon-App-60x60@3x", 180),
    ("Icon-App-76x76@1x", 76), ("Icon-App-76x76@2x", 152),
    ("Icon-App-83.5x83.5@2x", 167),
]

let iosDir = URL(fileURLWithPath: "ios/Runner/Assets.xcassets/AppIcon.appiconset")
for (name, size) in targets {
    try writePNG(size: size, to: iosDir.appendingPathComponent("\(name).png"))
}
print("\(targets.count) simge yazıldı → \(iosDir.path)")

// Android. Hedef şimdilik yalnızca App Store ama depoda varsayılan Flutter
// simgesi kalmasın — aynı çizim, Android'in yoğunluk klasörleri.
let android: [(String, Int)] = [
    ("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
    ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192),
]
let resDir = URL(fileURLWithPath: "android/app/src/main/res")
for (folder, size) in android {
    try writePNG(
        size: size,
        to: resDir.appendingPathComponent("\(folder)/ic_launcher.png"),
    )
}
print("\(android.count) simge yazıldı → \(resDir.path)")
