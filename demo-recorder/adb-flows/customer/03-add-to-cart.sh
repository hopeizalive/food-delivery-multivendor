#!/usr/bin/env bash
# Customer add-to-cart flow.
#
# The app has two different behaviors depending on the item's data (see
# Restaurant.js's addToCart): an item with exactly one variation and no
# addons is added straight to the cart on tap (no navigation); an item with
# variations/addons instead opens an ItemDetail customization screen with
# its own "item-detail-add-to-cart-button". Demo Bistro's current mock-api
# seed data (food-1..food-4) is all single-variation/no-addons, so today
# this always takes the quick-add path - but handle both so the flow still
# works if the seed data ever changes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== customer/03-add-to-cart ==="

tap_id "menu-food-item-food-1" || exit 1

# Poll for whichever of the two outcomes shows up first.
start=$SECONDS
outcome=""
while (( SECONDS - start < 15 )); do
  f=$(ui_dump)
  if grep -q 'text="VIEW YOUR CART"' "$f"; then
    outcome="quick-add"
    break
  fi
  if grep -q "id/item-detail-add-to-cart-button\|\"item-detail-add-to-cart-button\"" "$f"; then
    outcome="customize-sheet"
    break
  fi
  sleep 1
done

case "$outcome" in
  quick-add)
    _log "quick-add path (item has no variations/addons) - already in cart"
    ;;
  customize-sheet)
    _log "customize-sheet path - tapping item-detail add-to-cart button"
    tap_id "item-detail-add-to-cart-button" || exit 1
    if ! wait_for_text "VIEW YOUR CART" 10; then
      _log "FAILED: VIEW YOUR CART never appeared after customize-sheet add"
      exit 1
    fi
    ;;
  *)
    _log "FAILED: neither quick-add nor customize-sheet outcome appeared within 15s"
    exit 1
    ;;
esac

_log "PASSED: customer/03-add-to-cart"
