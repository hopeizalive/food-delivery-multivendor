#!/usr/bin/env bash
# Store app login flow, driven by raw adb shell (no WSL2/Maestro).
# Fully self-contained: cold-starts the app, handles the Expo dev-client
# chooser/connect screen and dev-menu overlay itself, then logs in.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

APP_ID="multivendor.enatega.restaurant"
APP_SCHEME="exp+enatega-multivendor-restaurant"
METRO_PORT="8082"

_log "=== store/01-login ==="

_log "force-stopping other demo apps to avoid focus stealing"
adb shell am force-stop com.enatega.multivendor >/dev/null 2>&1
adb shell am force-stop com.enatega.multirider >/dev/null 2>&1

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
  if grep -q 'text="Orders"\|text="Delivery Orders"\|text="Pick up Orders"' "$f"; then
    _log "store already logged in, on Orders screen"
    _log "PASSED: store/01-login"
    exit 0
  fi
  if grep -q 'store-login-username-input' "$f"; then
    _log "store login screen visible"
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

tap_id "store-login-username-input" || exit 1
clear_input
type_text "store-demo"
press_back
sleep 1

tap_id "store-login-password-input" || exit 1
clear_input
type_text "demo1234"
press_back
sleep 1

tap_id_retry "store-login-submit-button" 3 2 || { _log "FAILED: could not submit login"; exit 1; }

sleep 3
_log "PASSED: store/01-login (verify landing screen manually if unsure)"
