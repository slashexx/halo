#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from scripts/IconGen.swift. No Xcode needed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.build/icon"
ICONSET="$TMP/AppIcon.iconset"

rm -rf "$TMP"
mkdir -p "$ICONSET"

echo "==> rendering master icon"
swift "$ROOT/scripts/IconGen.swift" "$TMP/icon_1024.png"

echo "==> resizing iconset"
for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
cp "$TMP/icon_1024.png" "$ICONSET/icon_512x512@2x.png"

echo "==> building icns"
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo "==> wrote Resources/AppIcon.icns"
