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

# This screen has a continuously-ticking "Auto decline in" countdown, which
# re-renders every second - a swipe gesture that happens to land during one
# of those re-renders can get dropped by RN's touch responder entirely (a
# known RN gotcha, not a scroll-distance issue: confirmed by repeated
# uiautomator dumps showing Accept/Decline fully visible and correctly
# positioned well after a single swipe attempt was reported as having found
# nothing, meaning the swipe itself sometimes silently no-ops rather than
# under- or over-scrolling). A single swipe is a coin flip here, so retry
# it across the whole wait budget instead of firing it once.
if ! wait_for_id "store-accept-order-button" 4 && ! wait_for_text "Accept" 4; then
  found=""
  for _attempt in 1 2 3 4 5; do
    _log "accept button not visible, swiping up to reveal on tall order card (attempt $_attempt)"
    adb shell input swipe 540 1450 540 700
    if wait_for_id "store-accept-order-button" 3 || wait_for_text "Accept" 3; then
      found=1
      break
    fi
  done
  if [[ -z "$found" ]]; then
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
