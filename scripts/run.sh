#!/usr/bin/env bash
# Builds, bundles, and runs Halo with logs attached to this terminal.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"

"$ROOT/scripts/bundle.sh" "$CONFIG"

# Run the binary inside the bundle directly (keeps bundle identity for TCC,
# but streams stdout/stderr here instead of hiding logs like `open` would).
exec "$ROOT/.build/Halo.app/Contents/MacOS/Halo"
