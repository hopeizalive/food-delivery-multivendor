#!/usr/bin/env bash
# Set up one Expo app for a container build: install deps, write .env from
# the mock-api-backed template unless one already exists.
#
# Usage: setup-app.sh <app-dir> [--force] [--api-url <https://host>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

DEFAULT_BASE_URL="https://enatega-demo-mock-api.onrender.com"

APP_DIR=""
FORCE=0
BASE_URL="$DEFAULT_BASE_URL"

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --api-url) BASE_URL="$2"; shift 2 ;;
    -*) err "unknown flag: $1"; exit 1 ;;
    *) APP_DIR="$1"; shift ;;
  esac
done

if [ -z "$APP_DIR" ]; then
  err "usage: setup-app.sh <app-dir> [--force] [--api-url <https://host>]"
  exit 1
fi

TEMPLATE="$SCRIPT_DIR/env-templates/$APP_DIR.env"
if [ ! -f "$TEMPLATE" ]; then
  err "no env template for '$APP_DIR' (looked in $TEMPLATE)"
  exit 1
fi

APP_PATH="$ROOT/$APP_DIR"
if [ ! -d "$APP_PATH" ]; then
  err "app directory not found: $APP_PATH"
  exit 1
fi

# Derive a wss:// URL from the https:// base for the WS_URL token.
WS_URL="$(printf '%s' "$BASE_URL" | sed -E 's#^https://#wss://#; s#^http://#ws://#')"

log "[$APP_DIR] installing dependencies"
install_deps "$APP_PATH"

ENV_FILE="$APP_PATH/.env"
if [ -f "$ENV_FILE" ] && [ "$FORCE" -ne 1 ]; then
  log "[$APP_DIR] .env already exists, leaving it as-is (use --force to overwrite)"
else
  log "[$APP_DIR] writing .env from template (api: $BASE_URL)"
  sed -e "s#{{BASE_URL}}#$BASE_URL#g" -e "s#{{WS_URL}}#$WS_URL#g" "$TEMPLATE" > "$ENV_FILE"
fi

log "[$APP_DIR] done"
