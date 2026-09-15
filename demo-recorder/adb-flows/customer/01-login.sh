#!/usr/bin/env bash
# Customer login flow, driven by raw adb shell (no WSL2/Maestro).
#
# Fully self-contained: force-stops the app, launches it cold, handles the
# Expo dev-client's chooser screen and connect handshake itself, then logs in.
#
# Important lesson baked in here: pressing Back blindly at the very start is
# dangerous - on the dev-launcher's root chooser screen, Back EXITS the whole
# app rather than dismissing anything (confirmed - it dropped us back to the
# home launcher). So we only ever act on a screen after confirming via dump
# what's actually showing, never speculatively.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

APP_ID="com.enatega.multivendor"
APP_SCHEME="exp+enategamultivendor"
METRO_PORT="8081"

_log "=== customer/01-login ==="

_log "force-stopping other demo apps to avoid focus stealing"
adb shell am force-stop multivendor.enatega.restaurant >/dev/null 2>&1
adb shell am force-stop com.enatega.multirider >/dev/null 2>&1

_log "cold-starting $APP_ID via direct deep link (port $METRO_PORT)"
adb shell am force-stop "$APP_ID" >/dev/null 2>&1
sleep 1
launch_dev_client "$APP_ID" "$APP_SCHEME" "$METRO_PORT"

sleep 3
dismiss_dev_menu 8

if ! wait_for_text "Discovery" 60; then
  # Not on Discovery yet - check for a second, later dev-menu popup or a
  # genuine error before deciding what to do, rather than pressing Back blind.
  dismiss_dev_menu 4
  f=$(ui_dump)
  if grep -q 'runtime not ready\|RELOAD' "$f"; then
    _log "error overlay detected, dumping for diagnosis:"
    grep -o 'text="[^"]\+"' "$f" | head -10
    exit 1
  fi
  _log "FAILED: Discovery screen not visible and no known overlay detected either"
  exit 1
fi

tap_text "Profile" || exit 1
sleep 1

f=$(ui_dump)
if grep -q 'Logout\|demo@enatega.com\|Demo Customer' "$f"; then
  _log "customer already logged in, returning to Discovery"
  tap_text "Discovery" || true
  sleep 1
  _log "PASSED: customer/01-login"
  exit 0
fi

if ! wait_for_text "Continue with Email" 15; then
  f=$(ui_dump)
  if grep -q 'Logout\|demo@enatega.com\|Demo Customer' "$f"; then
    _log "customer already logged in, returning to Discovery"
    tap_text "Discovery" || true
    sleep 1
    _log "PASSED: customer/01-login"
    exit 0
  fi
  _log "FAILED: 'Continue with Email' never appeared on Profile tab"
  exit 1
fi
tap_text "Continue with Email" || exit 1

# Both the email and password EditText fields have empty resource-id AND
# empty content-desc on this build (confirmed via uiautomator dump) - the
# RN testID isn't reaching the native view here at all, so id-based lookup
# can never work. Their placeholder text ("Email"/"Password") is the only
# usable selector and has real (non-degenerate) bounds, unlike the tab bar.
if ! wait_for_text "Email" 15; then
  _log "FAILED: email input never appeared"
  exit 1
fi
tap_text "Email" || exit 1
type_text "demo@enatega.com"
press_back  # dismiss keyboard so the Continue button isn't covered
sleep 1

tap_text_retry "Continue" 3 2 || { _log "FAILED: could not advance past email step"; exit 1; }

if ! wait_for_text "Password" 15; then
  _log "FAILED: password input never appeared"
  exit 1
fi
tap_text "Password" || exit 1
type_text "demo1234"
press_back
sleep 1

# This submit button is labeled "Login", not "Continue" (confirmed via
# dump) - a different button from the email step's, not the same ID reused.
tap_text_retry "Login" 3 2 || { _log "FAILED: could not submit login"; exit 1; }

if ! wait_for_text "Discovery" 15; then
  _log "FAILED: did not land back on Discovery after login"
  exit 1
fi

_log "PASSED: customer/01-login"
