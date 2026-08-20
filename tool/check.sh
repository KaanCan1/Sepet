#!/usr/bin/env bash
# CI'ın çalıştırdığı denetimlerin birebir yereli.
#
# Sistemde Flutter'ınkinden farklı bir Dart SDK'sı varsa `dart format`
# başka bir biçimlendirici çalıştırır ve yerelde temiz görünen kod CI'da
# patlar. Bu yüzden Flutter'ın kendi Dart'ını doğrudan çağırıyoruz.
set -euo pipefail

FLUTTER_BIN="$(command -v flutter)"
FLUTTER_ROOT="$(cd "$(dirname "$(readlink "$FLUTTER_BIN" || echo "$FLUTTER_BIN")")/.." && pwd)"
DART="$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart"

if [[ ! -x "$DART" ]]; then
  echo "Flutter'ın Dart SDK'sı bulunamadı: $DART" >&2
  exit 1
fi

echo "→ Dart: $("$DART" --version 2>&1)"

echo "→ Bağımlılıklar"
flutter pub get

echo "→ Biçim"
"$DART" format --output=none --set-exit-if-changed .

echo "→ Statik analiz"
flutter analyze --fatal-infos

echo "→ Testler"
flutter test

echo "✓ Hepsi temiz"
