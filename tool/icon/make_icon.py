"""Sepet uygulama simgesi.

İşaret tek bir fikri taşıyor: sepetin kendisi endeks. Arabanın dikey
çıtaları yükselen bir dizi olarak çiziliyor — ana ekrandaki 40 piksellik
boyda araba çıtası gibi okunuyor, büyük boyda fiyat serisi gibi. Grafik
forma sonradan eklenmiyor, formun kendisinden çıkıyor.

Renkler uygulamanın paletinden: mürekkep kırmızısı zemin, kâğıt beyazı
işaret. Zemin düz — degrade işaretin sadeliğini zayıflatıyordu.

Yerleşim elle değil ölçüyle: işaret şeffaf katmana çiziliyor, gerçek
sınırları okunuyor, sonra ortalanıp ölçekleniyor. Elle konumlandırmada
sap ile tekerler kompozisyonu sürekli sola aşağı çekiyordu.
"""
from PIL import Image, ImageDraw

RED = (0x9F, 0x2F, 0x2D)
PAPER = (0xF7, 0xF6, 0xF3)

N = 1024          # nihai kenar
S = 4             # süperörnekleme
MARK = 0.60       # işaretin kenara oranı
RISE = 0.022      # optik ortalama: göz kütleyi biraz yukarıda ister
W = 48            # tek gövde kalınlığı — her çizgi bu kalınlıkta


def _stroke(d, pts, w=W):
    d.line([(x * S, y * S) for x, y in pts],
           fill=255, width=int(w * S), joint="curve")
    for x, y in (pts[0], pts[-1]):        # yuvarlak uçlar
        r = w * S / 2
        d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=255)


def _mark():
    """İşaret, şeffaf katmanda maske olarak."""
    m = Image.new("L", (N * S, N * S), 0)
    d = ImageDraw.Draw(m)

    # Sap: kısa yatay tutamak, sepetin sol üst köşesine inen diyagonal.
    _stroke(d, [(258, 312), (318, 312), (360, 424)])

    # Sepet: yamuk, üstü geniş.
    _stroke(d, [(360, 424), (800, 424), (722, 694), (466, 694), (360, 424)])

    # Çıtalar: yükselen dizi. Taban çizgisinin içinden başlıyorlar ki
    # gövdeye yapışık okunsunlar; üstte kalan boşluk kasıtlı — çıta üst
    # kenara değerse dizi kaybolup dolu bir kama gibi görünüyor.
    for x, top in ((508, 600), (578, 550), (648, 500)):
        _stroke(d, [(x, 694), (x, top)])

    # Tekerler: sepetin altında, gövdeyle aynı ağırlıkta iki nokta.
    for cx in (534, 690):
        r = 42 * S
        d.ellipse([cx * S - r, 792 * S - r, cx * S + r, 792 * S + r], fill=255)

    return m.crop(m.getbbox())


def build():
    mark = _mark()
    hedef = int(N * S * MARK)
    k = hedef / max(mark.size)
    mark = mark.resize((round(mark.width * k), round(mark.height * k)),
                       Image.LANCZOS)

    img = Image.new("RGB", (N * S, N * S), RED)
    img.paste(PAPER,
              ((N * S - mark.width) // 2,
               (N * S - mark.height) // 2 - int(N * S * RISE)),
              mark)
    return img.resize((N, N), Image.LANCZOS)


def write_appiconset(master, klasor):
    """Contents.json ne istiyorsa onu yazar.

    Boy listesini elle tutmak yerine katalogdan okumak, Xcode'un beklediği
    dosyalarla üretilenlerin ayrışmasını imkânsız kılıyor: eksik bir dosya
    derlemede değil, mağaza yüklemesinde patlıyor.
    """
    import io
    import json
    import os

    katalog = os.path.join(klasor, "Contents.json")
    with io.open(katalog, encoding="utf-8") as f:
        images = json.load(f)["images"]

    for im in images:
        ad = im.get("filename")
        if not ad:
            continue
        kenar = float(im["size"].split("x")[0]) * float(im["scale"].rstrip("x"))
        kenar = int(round(kenar))
        master.resize((kenar, kenar), Image.LANCZOS).save(
            os.path.join(klasor, ad))
        yield ad, kenar


if __name__ == "__main__":
    import sys

    master = build()
    if len(sys.argv) > 2 and sys.argv[1] == "--appicon":
        for ad, kenar in write_appiconset(master, sys.argv[2]):
            print(f"{ad}  {kenar}px")
    else:
        out = sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png"
        master.save(out)
        print(out)
