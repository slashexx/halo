#!/usr/bin/env bash
# Assembles Halo.app from the SwiftPM build product. No Xcode required.
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Halo"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP="$ROOT/.build/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

# Ad-hoc sign so the bundle has a stable identity for any TCC prompts. Note:
# the ad-hoc cdhash changes each build, so grants keyed to the signature (e.g.
# Accessibility, used later for keystroke/window actions) may need re-granting
# after a rebuild during development.
codesign --force --sign - --identifier com.openhalo.Halo "$APP" >/dev/null 2>&1 || true

echo "==> done: $APP"
