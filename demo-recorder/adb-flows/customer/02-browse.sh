#!/usr/bin/env bash
# Customer browse flow: Discovery -> Demo Bistro's menu.
# Prerequisite: customer app is on Discovery, logged in or guest.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
source lib/adb-ui.sh

_log "=== customer/02-browse ==="

if ! wait_for_text "Discovery" 10; then
  _log "PREREQUISITE FAILED: not on Discovery"
  exit 1
fi

tap_text "Demo Bistro" || exit 1

if ! wait_for_id "menu-food-item-food-1" 15; then
  _log "FAILED: menu item never appeared"
  exit 1
fi

_log "PASSED: customer/02-browse"
