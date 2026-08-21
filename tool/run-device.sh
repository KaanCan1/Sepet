#!/usr/bin/env bash
# Uygulamayı fiziksel iPhone'a kurar.
#
# Telefon localhost'a erişemez; dağıtılmış sunucunun adresi derleme zamanında
# geçiliyor. Ücretsiz Apple ID ile profil 7 gün geçerli — süre dolunca bu
# betiği tekrar çalıştırmak yeterli.
set -euo pipefail

cd "$(dirname "$0")/.."

API_URL="${SEPET_API_URL:-}"
if [[ -z "$API_URL" ]]; then
  echo "SEPET_API_URL tanımlı değil." >&2
  echo "Örnek: SEPET_API_URL=https://sepet-api.onrender.com $0" >&2
  exit 1
fi

if [[ "$API_URL" != https://* ]]; then
  echo "⚠ Adres HTTPS değil. iOS'un ATS kuralı düz HTTP'yi engelliyor;" >&2
  echo "  uygulama sunucuya bağlanamaz." >&2
fi

FLUTTER=(flutter)
command -v fvm >/dev/null 2>&1 && FLUTTER=(fvm flutter)

echo "→ Bağlı cihazlar"
"${FLUTTER[@]}" devices

DEVICE="${SEPET_DEVICE:-}"
ARGS=(run --release --dart-define=SEPET_API_URL="$API_URL")
[[ -n "$DEVICE" ]] && ARGS+=(-d "$DEVICE")

echo "→ Kuruluyor ($API_URL)"
exec "${FLUTTER[@]}" "${ARGS[@]}"
