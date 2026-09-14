#!/usr/bin/env bash
# Rider deliver-order flow: completes delivery and confirms the dialog.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== rider/04-deliver-order ==="

# Check if on order details screen or if "View order details" needs to be tapped
f=$(ui_dump)
if ! grep -q 'text="Mark as Delivered"' "$f" && ! grep -q 'text="MARK AS DELIVERED"' "$f"; then
  if wait_for_text "View order details" 10; then
    tap_text "View order details" || exit 1
    sleep 2
  fi
fi

if ! wait_for_text "Mark as Delivered" 15 && ! wait_for_id "rider-mark-delivered-button" 15; then
  # Check if alert dialog is already open
  f=$(ui_dump)
  if ! grep -q 'MARK AS DELIVERED' "$f"; then
    _log "FAILED: 'Mark as Delivered' button never appeared"
    exit 1
  fi
fi

f=$(ui_dump)
if ! grep -q 'MARK AS DELIVERED' "$f"; then
  tap_text "Mark as Delivered" || tap_id "rider-mark-delivered-button" || exit 1
  sleep 1
fi

if ! wait_for_text "MARK AS DELIVERED" 10; then
  _log "FAILED: confirmation alert dialog never appeared"
  exit 1
fi

tap_text "MARK AS DELIVERED" || exit 1
sleep 3

_log "PASSED: rider/04-deliver-order"
_log "=== RIDER FLOW COMPLETE ==="
