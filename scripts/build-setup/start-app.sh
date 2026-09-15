#!/usr/bin/env bash
# Start one Expo app's dev server so a physical device (scanning the QR /
# dev-client deep link) can reach it — in Codespaces this makes Metro
# advertise the Codespaces forwarded domain instead of its own internal
# LAN IP, so no --tunnel/ngrok is needed and multiple apps can run at once.
#
# Usage: start-app.sh <app-dir> <port>
#   e.g. start-app.sh multivendor-rider 8082
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

APP_DIR="${1:-}"
PORT="${2:-}"
if [ -z "$APP_DIR" ] || [ -z "$PORT" ]; then
  err "usage: start-app.sh <app-dir> <port>"
  exit 1
fi

APP_PATH="$ROOT/$APP_DIR"
if [ ! -d "$APP_PATH" ]; then
  err "app directory not found: $APP_PATH"
  exit 1
fi

FORWARDED_URL="$(codespaces_forwarded_url "$PORT")"
if [ -n "$FORWARDED_URL" ]; then
  export EXPO_PACKAGER_PROXY_URL="$FORWARDED_URL"
  log "[$APP_DIR] Codespaces detected — advertising $EXPO_PACKAGER_PROXY_URL instead of the internal LAN IP"
  log "[$APP_DIR] make sure port $PORT is set to Public in the Ports tab (or add it to devcontainer.json portsAttributes)"
else
  warn "[$APP_DIR] not running in Codespaces (or its env vars are missing) — falling back to Metro's default LAN URL"
fi

cd "$APP_PATH"
exec npx expo start --port "$PORT"
