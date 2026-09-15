#!/usr/bin/env bash
# Customer checkout flow: cart -> checkout screen.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== customer/04-checkout ==="

tap_text "VIEW YOUR CART" || exit 1

# The cart's Checkout button has no resource-id on this build (confirmed
# via uiautomator dump) - its own text is the real, non-degenerate-bounds
# selector.
if ! wait_for_text "Checkout" 15; then
  _log "FAILED: cart checkout button never appeared"
  exit 1
fi
tap_text "Checkout" || exit 1

# Same story: no resource-id on this build, use its own text.
if ! wait_for_text "Place Order" 15; then
  _log "FAILED: place-order button never appeared"
  exit 1
fi

_log "PASSED: customer/04-checkout"
