#!/bin/zsh
# Turns a 1024×1024 PNG into Resources/AppIcon.icns.  Usage: ./make-icon.sh brand/options/option-2.png
set -euo pipefail
cd "$(dirname "$0")"

SRC="${1:?1024x1024 PNG gerekli}"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"

for size in 16 32 128 256 512; do
    sips -z $size $size "$SRC" --out "$SET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$SRC" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Hazır: Resources/AppIcon.icns"
