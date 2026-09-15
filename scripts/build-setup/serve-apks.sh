#!/usr/bin/env bash
# Serve APKs built by build-apk.sh over a forwarded Codespaces port, with a
# generated index page showing one QR code per APK — scan with a phone
# camera to download it directly, no cable or manual URL typing needed.
#
# Usage: serve-apks.sh [port]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

PORT="${1:-9000}"
OUT_DIR="$ROOT/dist/apks"

if [ ! -d "$OUT_DIR" ] || [ -z "$(find "$OUT_DIR" -maxdepth 1 -name '*.apk' -print -quit)" ]; then
  err "no APKs found in $OUT_DIR — run scripts/build-setup/build-apk.sh <app-dir> first"
  exit 1
fi

BASE_URL="$(codespaces_forwarded_url "$PORT")"
if [ -z "$BASE_URL" ]; then
  warn "not running in Codespaces — QR codes will point at localhost and won't work from a phone"
  BASE_URL="http://localhost:$PORT"
fi

QR_DIR="$OUT_DIR/qr"
mkdir -p "$QR_DIR"

INDEX="$OUT_DIR/index.html"
{
  echo '<!doctype html><html><head><meta charset="utf-8"><title>Team APK downloads</title>'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
  echo '<style>body{font-family:sans-serif;padding:24px;max-width:720px;margin:0 auto}'
  echo '.card{border:1px solid #ddd;border-radius:8px;padding:16px;margin-bottom:16px;display:flex;gap:16px;align-items:center}'
  echo 'img{width:160px;height:160px}a.dl{display:inline-block;margin-top:8px;font-weight:bold}</style></head><body>'
  echo '<h1>Team APK downloads</h1><p>Scan a QR code with your phone camera to download that APK directly.</p>'
  for apk in "$OUT_DIR"/*.apk; do
    name="$(basename "$apk")"
    url="$BASE_URL/$name"
    qrfile="qr/${name%.apk}.png"
    log "generating QR for $name -> $url"
    npx --yes qrcode -o "$OUT_DIR/$qrfile" "$url" >/dev/null
    printf '<div class="card"><img src="%s" alt="QR for %s"><div><h3>%s</h3><a class="dl" href="%s">Download</a></div></div>\n' \
      "$qrfile" "$name" "$name" "$name"
  done
  echo '</body></html>'
} > "$INDEX"

log "serving $OUT_DIR at $BASE_URL"
log "make sure port $PORT is set to Public in the Ports tab (or add it to devcontainer.json)"
cd "$OUT_DIR"
exec npx --yes http-server . -p "$PORT" -a 0.0.0.0 --cors -c-1
