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

# Food item cards have neither a resource-id nor a content-desc matching
# their testID on this build (confirmed via uiautomator dump - content-desc
# there is a big composite accessibility label like "Loaded Nachos, Crispy
# nachos, cheese, jalapenos, $ 6.50, $ 13.00", not "menu-food-item-food-1").
# The category tab ("Starters") is a reliable, testID-independent signal
# that the menu actually rendered, without hardcoding one specific dish
# name from the fixture data.
if ! wait_for_text "Starters" 15; then
  _log "FAILED: menu never appeared"
  exit 1
fi

_log "PASSED: customer/02-browse"
