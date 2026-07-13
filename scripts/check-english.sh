#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if rg -n '[\p{Han}]' "$ROOT/Sources" "$ROOT/Resources/Web" "$ROOT/Info.plist" "$ROOT/README.md"; then
  echo "Non-English UI text found." >&2
  exit 1
fi
echo "English-only UI check passed."
