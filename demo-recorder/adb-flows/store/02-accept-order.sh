#!/usr/bin/env bash
# Store accept-order flow. Assumes a live order already exists (customer's
# place-order flow ran first) and the store app is logged in.
#
# Tapping the order's Accept button opens a "Set Preparation Time" bottom
# sheet - tapping Done (not "Accept and Print") is what actually fires the
# acceptOrder mutation (confirmed manually earlier this session).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== store/02-accept-order ==="

if ! wait_for_id "store-accept-order-button" 4 && ! wait_for_text "Accept" 4; then
  _log "accept button not immediately visible, swiping up to reveal on tall order card"
  adb shell input swipe 540 1800 540 800
  sleep 1
fi

if ! wait_for_id "store-accept-order-button" 10 && ! wait_for_text "Accept" 10; then
  # Try one more swipe just in case
  adb shell input swipe 540 1800 540 800
  sleep 1
  if ! wait_for_id "store-accept-order-button" 5 && ! wait_for_text "Accept" 5; then
    _log "FAILED: no order with an accept button visible"
    exit 1
  fi
fi
tap_id "store-accept-order-button" || tap_text "Accept" || exit 1

if ! wait_for_id "store-accept-order-done-button" 5 && ! wait_for_text "Done" 5; then
  _log "FAILED: prep-time sheet's Done button never appeared"
  exit 1
fi
tap_id "store-accept-order-done-button" || tap_text "Done" || exit 1

_log "PASSED: store/02-accept-order"
