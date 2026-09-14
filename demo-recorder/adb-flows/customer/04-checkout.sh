#!/usr/bin/env bash
# Customer checkout flow: cart -> checkout screen.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== customer/04-checkout ==="

tap_text "VIEW YOUR CART" || exit 1

if ! wait_for_id "customer-cart-checkout-button" 15; then
  _log "FAILED: cart checkout button never appeared"
  exit 1
fi
tap_id "customer-cart-checkout-button" || exit 1

if ! wait_for_id "customer-place-order-button" 15; then
  _log "FAILED: place-order button never appeared"
  exit 1
fi

_log "PASSED: customer/04-checkout"
