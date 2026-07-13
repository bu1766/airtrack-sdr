#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if rg -n '[\p{Han}]' "$ROOT/Sources" "$ROOT/Info.plist"; then
  echo "Native app defaults must remain English." >&2
  exit 1
fi

rg -q '<html lang="en">' "$ROOT/Resources/Web/index.html"
rg -q '<option value="en"[^>]*>English</option>' "$ROOT/Resources/Web/index.html"
rg -q '<option value="zh-CN"[^>]*>简体中文</option>' "$ROOT/Resources/Web/index.html"
rg -q 'const STORAGE_KEY = "airtrack-language"' "$ROOT/Resources/Web/i18n.js"
rg -q '"Start Tracking": "开始追踪"' "$ROOT/Resources/Web/i18n.js"
echo "English-default bilingual UI check passed."
