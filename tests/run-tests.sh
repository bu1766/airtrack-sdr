#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node --check "$ROOT/Resources/Web/script.js"
node --check "$ROOT/Resources/Web/receiver-control.js"
swiftc -typecheck -target "$(uname -m)-apple-macosx13.0" \
  -framework AppKit -framework WebKit -framework Network \
  "$ROOT/Sources/AirTrackSDR/main.swift"

rg -q 'id="routeRow"' "$ROOT/Resources/Web/index.html"
rg -q 'selected_aircraft_model' "$ROOT/Resources/Web/index.html"
rg -q 'Start Tracking' "$ROOT/Resources/Web/index.html"
rg -q '/api/receiver/devices' "$ROOT/Resources/Web/receiver-control.js"
rg -q '127\.0\.0\.1' "$ROOT/Sources/AirTrackSDR/main.swift"
rg -q 'cleanupOrphanedDecoder' "$ROOT/Sources/AirTrackSDR/main.swift"
rg -q 'Control Header Required' "$ROOT/Sources/AirTrackSDR/main.swift"

gzip -t "$ROOT/Resources/Web/db2/icao_aircraft_types2.js"
gzip -dc "$ROOT/Resources/Web/db2/icao_aircraft_types2.js" | jq -e '.A359[0] == "AIRBUS A-350-900"' >/dev/null

"$ROOT/scripts/check-english.sh"
echo "All source tests passed."
