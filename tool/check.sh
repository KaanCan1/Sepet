#!/usr/bin/env bash
# CI'ın çalıştırdığı denetimlerin birebir yereli.
#
# Proje Flutter sürümü .fvmrc'de sabit. FVM kuruluysa onu kullanıyoruz; değilse
# global flutter'a düşüp uyarı veriyoruz, çünkü sürüm farkı biçimlendiriciyi
# değiştirip yerelde temiz görünen kodu CI'da patlatabiliyor.
set -euo pipefail

cd "$(dirname "$0")/.."

PINNED="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .fvmrc)"

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
  DART=(fvm dart)
else
  echo "⚠ FVM bulunamadı, global flutter kullanılıyor."
  echo "  Proje $PINNED sürümüne sabit. Kurmak için: brew tap leoafarias/fvm && brew install fvm && fvm use $PINNED"
  FLUTTER=(flutter)
  DART=(dart)
fi

ACTIVE="$("${FLUTTER[@]}" --version 2>/dev/null | sed -n '1s/Flutter \([0-9.]*\).*/\1/p')"
echo "→ Flutter $ACTIVE (sabitlenen: $PINNED)"
if [[ "$ACTIVE" != "$PINNED" ]]; then
  echo "⚠ Sürüm uyuşmuyor — CI farklı sonuç verebilir." >&2
fi

echo "→ Bağımlılıklar"
"${FLUTTER[@]}" pub get

echo "→ Biçim"
"${DART[@]}" format --output=none --set-exit-if-changed .

echo "→ Sunucu tip denetimi"
(cd server && npm run --silent typecheck)

echo "→ Statik analiz"
"${FLUTTER[@]}" analyze --fatal-infos

echo "→ Testler"
"${FLUTTER[@]}" test

echo "✓ Hepsi temiz"
