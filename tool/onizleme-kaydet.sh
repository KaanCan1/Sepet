#!/usr/bin/env bash
#
# App Preview kliplerini kaydeder ve goldie'nin çekim bildirimine yazar.
#
# NEDEN AYRI BİR BETİK. Durum çubuğunu asıl yöneten argent: flow-execute her
# akıştan önce KOŞULSUZ kendi çubuğunu sabitliyor (`--time 9:37`, yalnızca
# --wifiBars ve --cellularBars) ve akış bitince finally içinde
# `simctl status_bar clear` çağırıyor. Kapatma bayrağı yok.
#
# İlk denemede video 09:37'de başlayıp 13:42'de bitiyordu ve sinyal gri
# noktalara dönüyordu; sebebi buydu — goldie segmentin holdSeconds'ını KAYIT
# İÇİNDE bekletiyor, yani argent'ın temizlemesi klibin son saniyelerine
# düşüyordu. Çözüm zamanlama: klip akışın bittiği yerde bitiyor, bekleme
# kendi segmentine alınıyor (bkz. store-preview-05-paylas).
#
# Buradaki pin argent'ınkini engellemiyor; argent yalnızca adını verdiği
# alanları eziyor, dolayısıyla --wifiMode/--cellularMode/--dataNetwork
# buradan geliyor ve çubuk sinyalli görünüyor. Saat argent'ın 9:37'si oluyor.
#
# Klipler yine goldie'nin akışlarıyla (.argent/flows/store-preview-*.yaml) ve
# argent'ın kendi kaydediciyle alınıyor; değişen tek şey zamanlama. Sonra
# `goldie preview` bu kliplerden videoyu üretiyor.
#
# Kullanım:  tool/onizleme-kaydet.sh
# Önkoşul :  yerel sunucu ayakta, uygulama SEPET_DEMO_EMAIL=vitrin@sepet.app
#            ile derlenip simülatöre kurulmuş olmalı (bkz. goldie.config.ts).
set -euo pipefail

UDID="${SEPET_UDID:-2E34F662-C338-4A54-81DD-9B9C90039F76}"
BUNDLE="com.kaancankurt.sepet"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
HAM="$KOK/goldie/out/raw/iphone-6.9"

# Pin'in oturması için beklenen saniye. Saati bu belirlemiyor (argent
# akış başında 9:37'ye çeviriyor); buradaki payın işi, argent'ın DOKUNMADIĞI
# alanların — wifiMode, cellularMode, dataNetwork — kayıt başlamadan yerine
# oturması. Onlar olmadan çubuk sinyalsiz görünüyor.
OTURMA=6

# goldie'nin pinStatusBar'ıyla birebir aynı bayraklar. Saat yine de 9:41
# çıkmıyor: goldie karelerde pin'i AKIŞTAN SONRA uyguladığı için ekran
# görüntüleri 09:41, video ise argent'ın 09:37'si oluyor. Aradaki dört
# dakikalık fark dışarıdan kapatılamıyor — argent'ın pin'i koşulsuz.
pinle() {
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged --batteryLevel 100 \
    --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --dataNetwork 5g
}

# id:akış:bekleme  — sıra goldie.config.ts'teki segments dizisiyle aynı olmalı
SEGMENTLER=(
  "endeks:store-preview-01-endeks:0"
  "kirilim:store-preview-02-kirilim:0"
  "urun:store-preview-03-urun:0"
  "kart:store-preview-04-kart:0"
  "paylas:store-preview-05-paylas:0"
)

mkdir -p "$HAM"
cd "$KOK"

echo "uygulama yeniden başlatılıyor"
argent run restart-app --udid "$UDID" --bundleId "$BUNDLE" >/dev/null
argent run await-screen-idle --udid "$UDID" --timeoutMs 60000 >/dev/null 2>&1 || true

SURELER=()
for kayit in "${SEGMENTLER[@]}"; do
  id="${kayit%%:*}"; kalan="${kayit#*:}"
  akis="${kalan%%:*}"; bekle="${kalan##*:}"

  echo "  segment $id"
  pinle
  sleep "$OTURMA"

  argent run screen-recording-start --udid "$UDID" \
    --timeLimitSeconds 120 --trimStatic false --showTouches false >/dev/null
  argent flow run "$akis" --device "$UDID" >/dev/null
  [ "$bekle" != "0" ] && sleep "$bekle"
  cikti="$(argent run screen-recording-stop --udid "$UDID" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["video"])')"

  cp "$cikti" "$HAM/onizleme-$id.mp4"
  sure="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$HAM/onizleme-$id.mp4")"
  SURELER+=("$id=$sure")
  printf "    %.1f sn\n" "$sure"
done

# Bildirimdeki klip süreleri `goldie preview` tarafından 15-30 sn kontrolünde
# kullanılıyor; yeni kliplerle güncelleniyor.
SURELER="${SURELER[*]}" HAM="$HAM" python3 - <<'PY'
import json, os

ham = os.environ["HAM"]
sureler = dict(p.split("=") for p in os.environ["SURELER"].split())
yol = os.path.join(ham, "manifest.json")
m = json.load(open(yol))

m["preview"] = {
    "sceneId": "onizleme",
    "clips": [
        {
            "segmentId": sid,
            "file": os.path.join(ham, f"onizleme-{sid}.mp4"),
            "durationSeconds": round(float(sureler[sid]), 3),
        }
        for sid in ["endeks", "kirilim", "urun", "kart", "paylas"]
    ],
}
json.dump(m, open(yol, "w"), indent=2, ensure_ascii=False)

toplam = sum(c["durationSeconds"] for c in m["preview"]["clips"])
print(f"  toplam {toplam:.1f} sn  (Apple: 15-30)")
PY

echo "bitti — şimdi: GOLDIE_CONFIG=goldie/goldie.config.ts npx -y goldie@0 preview"
