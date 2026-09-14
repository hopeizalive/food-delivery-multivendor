#!/usr/bin/env bash
# Rider claim-order flow: claims the accepted order from the "New Orders" list.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== rider/02-claim-order ==="

# Check if already assigned or if "Assign me" is visible
f=$(ui_dump)
if grep -q 'text="ASSIGNED"' "$f"; then
  _log "order already in ASSIGNED status"
  _log "PASSED: rider/02-claim-order"
  exit 0
fi

if ! wait_for_text "Assign me" 15 && ! wait_for_id "rider-assign-order-button" 15; then
  _log "FAILED: no order with 'Assign me' button visible"
  exit 1
fi

tap_text "Assign me" || tap_id "rider-assign-order-button" || exit 1
sleep 2

if ! wait_for_text "ASSIGNED" 15; then
  _log "FAILED: order did not transition to ASSIGNED"
  exit 1
fi

_log "PASSED: rider/02-claim-order"
