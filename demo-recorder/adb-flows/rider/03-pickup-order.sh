#!/usr/bin/env bash
# Rider pickup-order flow: opens order details and marks the order as picked up.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== rider/03-pickup-order ==="

# Check if already on order details or if "View order details" needs to be tapped
f=$(ui_dump)
if ! grep -q 'text="Pick up"' "$f" && ! grep -q 'text="Mark as Delivered"' "$f"; then
  if wait_for_text "View order details" 10; then
    tap_text "View order details" || exit 1
    sleep 2
  fi
fi

# Check if already picked up
f=$(ui_dump)
if grep -q 'text="Mark as Delivered"' "$f"; then
  _log "order already in PICKED status (Mark as Delivered visible)"
  _log "PASSED: rider/03-pickup-order"
  exit 0
fi

# The Pick up button sits below the initial viewport on the order-details
# screen (confirmed via uiautomator dump: a map view fills most of the
# screen above it) - unlike store's accept-order screen, nothing here
# scrolls the content into view on its own, so wait_for_text alone would
# wait out its full timeout no matter how long, never seeing it appear.
if ! wait_for_text "Pick up" 4 && ! wait_for_id "rider-pickup-button" 4; then
  _log "'Pick up' not immediately visible, swiping up to reveal below the map"
  adb shell input swipe 360 1300 360 700
  sleep 1
fi

if ! wait_for_text "Pick up" 15 && ! wait_for_id "rider-pickup-button" 15; then
  _log "FAILED: 'Pick up' button never appeared"
  exit 1
fi

tap_text "Pick up" || tap_id "rider-pickup-button" || exit 1
sleep 2

if ! wait_for_text "Mark as Delivered" 15; then
  _log "FAILED: did not transition to PICKED (Mark as Delivered button not found)"
  exit 1
fi

_log "PASSED: rider/03-pickup-order"
