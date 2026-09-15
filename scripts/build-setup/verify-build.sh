#!/usr/bin/env bash
# Confirm each Expo app actually builds at the JS level in this container:
# typecheck + lint (check-only, no writes), and optionally a real Metro
# bundle via `expo export` with --full. Run scripts/build-setup/setup-all.sh
# first so dependencies and .env files exist.
#
# Usage: verify-build.sh [--full] [app-dir ...]
#   --full          also run `expo export` (slower, needs network access
#                    for Metro/Expo's dependency resolution)
#   [app-dir ...]   only verify the named app(s)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

ALL_APPS=(multivendor-app multivendor-rider multivendor-store)

FULL=0
APPS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1; shift ;;
    -*) err "unknown flag: $1"; exit 1 ;;
    *) APPS+=("$1"); shift ;;
  esac
done
[ "${#APPS[@]}" -eq 0 ] && APPS=("${ALL_APPS[@]}")

FAILED=()

verify_app() {
  local app="$1"
  local dir="$ROOT/$app"

  if [ ! -d "$dir/node_modules" ]; then
    err "[$app] node_modules missing — run scripts/build-setup/setup-all.sh first"
    FAILED+=("$app")
    return
  fi

  log "[$app] typecheck"
  if ! (cd "$dir" && npx tsc --noEmit); then
    FAILED+=("$app (typecheck)")
  fi

  log "[$app] lint"
  case "$app" in
    multivendor-app)
      (cd "$dir" && npx eslint . --ext .js) || FAILED+=("$app (lint)")
      ;;
    multivendor-rider)
      (cd "$dir" && npx eslint .) || FAILED+=("$app (lint)")
      ;;
    multivendor-store)
      (cd "$dir" && npm run lint) || FAILED+=("$app (lint)")
      ;;
  esac

  if [ "$FULL" -eq 1 ]; then
    log "[$app] expo export (this can take a while)"
    local out
    out="$(mktemp -d)"
    if (cd "$dir" && npx expo export --platform all --output-dir "$out"); then
      rm -rf "$out"
    else
      FAILED+=("$app (expo export)")
    fi
  fi
}

for app in "${APPS[@]}"; do
  verify_app "$app"
done

if [ "${#FAILED[@]}" -eq 0 ]; then
  log "all builds verified: ${APPS[*]}"
  exit 0
else
  err "failed: ${FAILED[*]}"
  exit 1
fi
