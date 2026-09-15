#!/usr/bin/env bash
# One-shot setup for testing all three Expo apps on a physical Android
# device connected over USB (adb). Verifies the device, wires up
# `adb reverse` for each app's Metro port so the device can reach Metro
# over the USB cable (no Wi-Fi/LAN needed), and starts any Metro bundlers
# that aren't already running.
#
# Usage: scripts/build-setup/setup-device.sh [customer|store|rider|all]
#   (default: all)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

TARGET="${1:-all}"

declare -A APP_DIR=(
  [customer]="multivendor-app"
  [store]="multivendor-store"
  [rider]="multivendor-rider"
)
declare -A APP_PORT=(
  [customer]=8081
  [store]=8082
  [rider]=8083
)

case "$TARGET" in
  all) APPS=(customer store rider) ;;
  customer|store|rider) APPS=("$TARGET") ;;
  *) err "usage: setup-device.sh [customer|store|rider|all]"; exit 1 ;;
esac

# 1. Device check
if ! command -v adb >/dev/null 2>&1; then
  err "adb not found on PATH. Install Android platform-tools first."
  exit 1
fi

DEVICE_LINES="$(adb devices | tail -n +2 | sed '/^$/d')"
DEVICE_COUNT="$(printf '%s\n' "$DEVICE_LINES" | grep -c $'\tdevice$' || true)"

if [ "$DEVICE_COUNT" -eq 0 ]; then
  err "no device connected. Plug in the phone via USB, enable USB debugging, and accept the 'Allow USB debugging?' prompt."
  printf '%s\n' "$DEVICE_LINES" >&2
  exit 1
fi
if [ "$DEVICE_COUNT" -gt 1 ]; then
  warn "multiple devices detected, using the first one listed. Set ANDROID_SERIAL to pin a specific one."
fi

DEVICE_ID="$(printf '%s\n' "$DEVICE_LINES" | grep $'\tdevice$' | head -n1 | cut -f1)"
log "using device: $DEVICE_ID"

# 2. Reverse tunnels — lets the USB-connected device reach 127.0.0.1:<port>
#    on this machine as its own localhost:<port>, so Metro's QR/dev-client
#    deep link (which points at localhost) works with no LAN/Wi-Fi step.
for app in "${APPS[@]}"; do
  port="${APP_PORT[$app]}"
  adb -s "$DEVICE_ID" reverse "tcp:$port" "tcp:$port" >/dev/null
  log "adb reverse tcp:$port <-> tcp:$port ($app)"
done

# 3. Start Metro for any app not already running, skip ones that are.
is_port_listening() {
  local port="$1"
  if command -v netstat >/dev/null 2>&1; then
    netstat -ano 2>/dev/null | grep -q ":$port[^0-9].*LISTENING"
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && exec 3<&- 3>&-
  fi
}

for app in "${APPS[@]}"; do
  dir="${APP_DIR[$app]}"
  port="${APP_PORT[$app]}"
  app_path="$ROOT/$dir"

  if [ ! -d "$app_path" ]; then
    warn "[$app] directory not found: $app_path — skipping"
    continue
  fi

  if is_port_listening "$port"; then
    log "[$app] Metro already running on port $port — leaving it as-is"
    continue
  fi

  log "[$app] starting Metro on port $port"
  log_file="$app_path/.metro-$port.log"
  (cd "$app_path" && nohup npx expo start --port "$port" >"$log_file" 2>&1 &)
  echo "$app" >> /dev/null # no-op, keeps shellcheck quiet about unused
done

# 4. Wait for each requested app's port to come up, then report status.
log "waiting for Metro bundlers to come up..."
for app in "${APPS[@]}"; do
  port="${APP_PORT[$app]}"
  dir="${APP_DIR[$app]}"
  [ -d "$ROOT/$dir" ] || continue

  for _ in $(seq 1 30); do
    is_port_listening "$port" && break
    sleep 1
  done

  if is_port_listening "$port"; then
    log "[$app] ready — http://localhost:$port (device reaches it via adb reverse)"
  else
    err "[$app] Metro did not come up on port $port — check $ROOT/$dir/.metro-$port.log"
  fi
done

cat <<EOF

Next steps on the device:
  - Open the Expo dev-client / app build already installed on the phone.
  - It should connect automatically via the USB reverse tunnel(s) above.
  - If an app shows a "no bundler found" screen, shake the device (or
    run: adb -s $DEVICE_ID shell input keyevent 82) and pick "Change bundle
    location" -> host "localhost", the app's port from the list above.

Re-run this script any time the device is reconnected (adb reverse tunnels
do not survive a USB replug).
EOF
