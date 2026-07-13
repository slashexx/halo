#!/usr/bin/env bash
# Builds a release Halo.app and packages it into a drag-to-install DMG.
# NOTE: this DMG is NOT code-signed or notarized (needs an Apple Developer ID +
# full Xcode). Gatekeeper will warn until you notarize — see README.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/Halo.app"
DMG="$ROOT/.build/Halo.dmg"
STAGE="$ROOT/.build/dmg-stage"

# Refresh the icon and build a release bundle.
[ -f "$ROOT/Resources/AppIcon.icns" ] || "$ROOT/scripts/make-icon.sh"
"$ROOT/scripts/bundle.sh" release

echo "==> staging DMG"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Halo.app"
ln -s /Applications "$STAGE/Applications"

echo "==> creating DMG"
hdiutil create -volname "Halo" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "==> wrote $DMG"
