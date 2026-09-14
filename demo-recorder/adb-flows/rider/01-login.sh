#!/usr/bin/env bash
# Rider app login flow, driven by raw adb shell (no WSL2/Maestro).
# Fully self-contained: cold-starts the app via direct deep link,
# dismisses dev-menu overlays, and logs in if needed.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

APP_ID="com.enatega.multirider"
APP_SCHEME="exp+food-delivery-rider-multivendor"
METRO_PORT="8083"

_log "=== rider/01-login ==="

_log "force-stopping other demo apps to avoid focus stealing"
adb shell am force-stop com.enatega.multivendor >/dev/null 2>&1
adb shell am force-stop multivendor.enatega.restaurant >/dev/null 2>&1

_log "cold-starting $APP_ID via direct deep link (port $METRO_PORT)"
adb shell am force-stop "$APP_ID" >/dev/null 2>&1
sleep 1
launch_dev_client "$APP_ID" "$APP_SCHEME" "$METRO_PORT"

sleep 3
dismiss_dev_menu 8

# Poll for either already logged in (Orders screen) OR login screen
found_screen=""
start=$SECONDS
while (( SECONDS - start < 35 )); do
  f=$(ui_dump)
  if dismiss_known_alerts "$f"; then
    sleep 1
    continue
  fi
  if grep -q 'text="Orders"\|text="New Orders"' "$f"; then
    _log "already logged in, on Orders screen"
    _log "PASSED: rider/01-login"
    exit 0
  fi
  if grep -q 'rider-login-username-input' "$f"; then
    _log "rider login screen visible"
    found_screen="login"
    break
  fi
  if grep -q 'text="Continue"\|text="Reload"' "$f"; then
    dismiss_dev_menu 4
  fi
  sleep 1
done

if [[ -z "$found_screen" ]]; then
  _log "FAILED: neither Orders dashboard nor login screen appeared"
  f=$(ui_dump)
  grep -o 'text="[^"]\+"' "$f" | head -10
  exit 1
fi
  tap_id "rider-login-username-input" || exit 1
  clear_input
  type_text "rider-demo"
  press_back
  sleep 1

  tap_id "rider-login-password-input" || exit 1
  clear_input
  type_text "demo1234"
  press_back
  sleep 1

  tap_id_retry "rider-login-submit-button" 3 2 || { _log "FAILED: could not submit rider login"; exit 1; }
  sleep 3
fi

if ! wait_for_text "Orders" 20; then
  _log "FAILED: did not land on Orders dashboard after login"
  exit 1
fi

_log "PASSED: rider/01-login"
