#!/usr/bin/env bash
# Check whether all three apps' debug APKs (from build-apk.sh) exist in
# dist/apks/ yet, before you bother running serve-apks.sh.
#
# Usage: check-apks.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

APPS=(multivendor-app multivendor-rider multivendor-store)
OUT_DIR="$ROOT/dist/apks"
MISSING=()

for app in "${APPS[@]}"; do
  apk="$OUT_DIR/$app-debug.apk"
  if [ -f "$apk" ]; then
    SIZE="$(du -h "$apk" | cut -f1)"
    MTIME="$(date -r "$apk" '+%Y-%m-%d %H:%M')"
    log "OK   $app -- $SIZE, built $MTIME"
  else
    err "MISSING $app -- $apk"
    MISSING+=("$app")
  fi
done

echo
if [ "${#MISSING[@]}" -eq 0 ]; then
  log "all three debug APKs are built. Ready for: bash scripts/build-setup/serve-apks.sh"
  exit 0
else
  err "missing: ${MISSING[*]}"
  for app in "${MISSING[@]}"; do
    err "  bash scripts/build-setup/build-apk.sh $app"
  done
  exit 1
fi
