#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${AIRTRACK_APP_PATH:-$(cat "$ROOT/dist/.app-path")}" 
test -x "$APP/Contents/MacOS/AirTrackSDR"
test -x "$APP/Contents/MacOS/dump1090"
test -x "$APP/Contents/MacOS/rtl_test"
test -x "$APP/Contents/MacOS/bladeRF-cli"
test -f "$APP/Contents/Resources/Web/index.html"
test -f "$APP/Contents/Resources/Web/db2/icao_aircraft_types2.js"
codesign --verify --deep --strict "$APP"
if otool -L "$APP/Contents/MacOS/dump1090" | rg '/opt/homebrew|/usr/local'; then
  echo "Homebrew dependency leaked into the app bundle." >&2
  exit 1
fi
echo "Bundle verification passed."
