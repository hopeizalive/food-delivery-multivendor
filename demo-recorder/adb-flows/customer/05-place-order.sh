#!/usr/bin/env bash
# Customer place-order flow: checkout -> Track Order.
#
# Placing the first order of an app-data lifetime triggers Android's native
# notification-permission dialog ("Allow Enatega Multi to send you
# notifications?"), which sits on top of and blocks the Track Order screen
# until dismissed (confirmed empirically). Handle it if it shows up.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== customer/05-place-order ==="

# No resource-id on this build (confirmed via uiautomator dump) - use text.
tap_text "Place Order" || exit 1

# Give the native permission dialog a moment to appear, and dismiss it if so.
sleep 2
f=$(ui_dump)
if grep -q 'send you notifications' "$f"; then
  _log "notification-permission dialog detected, allowing"
  tap_text "Allow" || true
  sleep 1
fi

if ! wait_for_text "Track Order" 45; then
  _log "FAILED: Track Order never appeared after placing order"
  exit 1
fi

_log "PASSED: customer/05-place-order"
_log "=== CUSTOMER FLOW COMPLETE ==="
