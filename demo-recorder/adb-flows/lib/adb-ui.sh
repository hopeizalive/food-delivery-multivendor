#!/usr/bin/env bash
# Minimal local UI-automation library built directly on `adb shell` + uiautomator.
# No WSL2, no Maestro - runs natively in Git Bash on Windows against a Windows adb server.
#
# Usage: source this file, then call the functions below from a flow script.
# Every function logs a one-line action to stdout so a run is readable as a transcript.

set -uo pipefail

DEMO_DUMP_DIR="${DEMO_DUMP_DIR:-/tmp/demo-dumps}"
mkdir -p "$DEMO_DUMP_DIR"

_log() { echo "[$(date +%H:%M:%S)] $*"; }

# Pull a fresh uiautomator dump to $DEMO_DUMP_DIR/current.xml and echo its path.
# uiautomator logs "could not get idle state" on any screen with a
# continuously-ticking element (e.g. the store app's auto-decline countdown)
# - it internally waits ~10s for idle, gives up, and dumps the current state
# anyway. That dump is normally still perfectly usable, so we do NOT retry on
# the warning text alone (each retry would re-pay that same ~10s internal
# wait, turning a single call into 50s+ for no benefit - measured directly).
# Only retry if the pulled file is actually unusable (empty/corrupt), which
# a real transient adb hiccup would produce, and cap it at 2 fast retries.
ui_dump() {
  local out="$DEMO_DUMP_DIR/current.xml"
  local attempt
  for attempt in 1 2 3; do
    adb shell uiautomator dump //sdcard/demo_dump.xml >/dev/null 2>&1
    adb pull //sdcard/demo_dump.xml "$out" >/dev/null 2>&1
    if [[ -s "$out" ]] && grep -q '<?xml' "$out" 2>/dev/null; then
      echo "$out"
      return 0
    fi
    sleep 0.3
  done
  # Last resort: whatever we last managed to pull, even if suspect - callers
  # already handle "text not found" gracefully via their own retry loops.
  echo "$out"
}

# Extract "x1,y1,x2,y2" for the first node whose resource-id ends with the given id.
# (RN's testID becomes the full package-qualified resource-id on Android, but we
# match suffix so callers just pass the plain testID.)
_bounds_by_id() {
  local id="$1" file="$2"
  grep -o "resource-id=\"[^\"]*${id}\"[^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" "$file" \
    | head -1 \
    | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | grep -o '[0-9]\+' | tr '\n' ',' | sed 's/,$//'
}

# Extract "x1,y1,x2,y2" for the first node with an exact text match.
_bounds_by_text() {
  local text="$1" file="$2"
  grep -o "text=\"${text}\"[^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" "$file" \
    | head -1 \
    | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | grep -o '[0-9]\+' | tr '\n' ',' | sed 's/,$//'
}

# Extract "x1,y1,x2,y2" for the first node with an exact content-desc match.
# Some elements (e.g. Expo dev-launcher's server-list rows) put their label in
# content-desc on the actual clickable node while the visible text sits on a
# separate non-clickable child - content-desc is the more reliable target there.
_bounds_by_desc() {
  local desc="$1" file="$2"
  grep -o "content-desc=\"${desc}\"[^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" "$file" \
    | head -1 \
    | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | grep -o '[0-9]\+' | tr '\n' ',' | sed 's/,$//'
}

# Extract "x1,y1,x2,y2" for the Nth (1-indexed) android.widget.EditText
# node in document order (matches visual top-to-bottom order for a simple
# login form). Fallback for fields with neither resource-id, content-desc,
# nor a stable placeholder text - confirmed on the store/rider login
# screens, whose username/password EditTexts show a remembered/pre-filled
# value (e.g. "FalafelTmeer@yopmail.com") instead of empty placeholder
# text, so text-based matching can't target them reliably either.
_bounds_by_nth_edittext() {
  local n="$1" file="$2"
  grep -o '<node[^>]*class="android\.widget\.EditText"[^>]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"[^>]*/>' "$file" \
    | sed -n "${n}p" \
    | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | grep -o '[0-9]\+' | tr '\n' ',' | sed 's/,$//'
}

_center_of() {
  local b="$1"
  local x1 y1 x2 y2
  IFS=',' read -r x1 y1 x2 y2 <<< "$b"
  echo "$(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))"
}

# Auto-dismiss known blocking system/emulator dialogs if present
dismiss_known_alerts() {
  local f="$1"
  if grep -q 'Must use physical device for Push Notifications' "$f"; then
    _log "auto-dismissing push notification alert"
    local b; b=$(_bounds_by_text "OK" "$f")
    if [[ -n "$b" ]]; then
      local xy; xy=$(_center_of "$b")
      adb shell input tap $xy
    else
      adb shell input keyevent 4
    fi
    return 0
  fi
  if grep -q 'send you notifications' "$f"; then
    _log "auto-dismissing permission dialog"
    local b; b=$(_bounds_by_text "Allow" "$f")
    if [[ -n "$b" ]]; then
      local xy; xy=$(_center_of "$b")
      adb shell input tap $xy
    fi
    return 0
  fi
  # Adding an item from a different restaurant than whatever's already in
  # the cart. Confirmed to occur in practice: a leftover cart from a
  # different restaurant (e.g. a previous run that failed mid-flow before
  # reaching checkout) blocks 03-add-to-cart's tap with this dialog
  # instead of adding the item. Tapping OK clears the stale cart and
  # proceeds with the current restaurant, which is what every flow wants.
  if grep -q 'items you.ve added to cart will be cleared' "$f"; then
    _log "auto-dismissing switch-restaurant cart-clear dialog"
    local b; b=$(_bounds_by_text "OK" "$f")
    if [[ -n "$b" ]]; then
      local xy; xy=$(_center_of "$b")
      adb shell input tap $xy
    fi
    return 0
  fi
  # Rider app's own in-app permission-priming dialog (not an OS dialog),
  # confirmed to appear right after claiming an order and block the
  # ASSIGNED-status check behind it. "Not now" avoids also triggering the
  # real OS location-permission dialog on top of it - live GPS tracking
  # isn't needed to validate order-lifecycle state transitions.
  if grep -q 'Allow background location for live delivery tracking' "$f"; then
    _log "auto-dismissing rider location-tracking priming dialog"
    local b; b=$(_bounds_by_text "Not now" "$f")
    if [[ -n "$b" ]]; then
      local xy; xy=$(_center_of "$b")
      adb shell input tap $xy
    fi
    return 0
  fi
  return 1
}

# wait_for_id <testID> [timeoutSeconds]  -- polls, returns 0 once found, 1 on timeout.
# Uses wall-clock time (SECONDS), not an iteration count - each dump+pull
# round trip can itself take several seconds, so counting iterations as
# seconds under-counts real elapsed time and lets a "15s" wait silently run 3-4x longer.
wait_for_id() {
  local id="$1" timeout="${2:-15}" start=$SECONDS
  while (( SECONDS - start < timeout )); do
    local f; f=$(ui_dump)
    if dismiss_known_alerts "$f"; then
      sleep 1
      continue
    fi
    local b; b=$(_bounds_by_id "$id" "$f")
    if [[ -n "$b" ]]; then
      _log "found id=$id after $((SECONDS - start))s"
      return 0
    fi
    sleep 1
  done
  _log "TIMEOUT waiting for id=$id (${timeout}s)"
  return 1
}

# wait_for_text <exact text> [timeoutSeconds]
wait_for_text() {
  local text="$1" timeout="${2:-15}" start=$SECONDS
  while (( SECONDS - start < timeout )); do
    local f; f=$(ui_dump)
    if dismiss_known_alerts "$f"; then
      sleep 1
      continue
    fi
    local b; b=$(_bounds_by_text "$text" "$f")
    if [[ -n "$b" ]]; then
      _log "found text=\"$text\" after $((SECONDS - start))s"
      return 0
    fi
    sleep 1
  done
  _log "TIMEOUT waiting for text=\"$text\" (${timeout}s)"
  return 1
}

# tap_id <testID> -- fails (returns 1) if not currently visible; caller should wait_for_id first.
tap_id() {
  local id="$1"
  local f; f=$(ui_dump)
  local b; b=$(_bounds_by_id "$id" "$f")
  if [[ -z "$b" ]]; then
    _log "tap_id FAILED - id=$id not found"
    return 1
  fi
  local xy; xy=$(_center_of "$b")
  _log "tap id=$id at ($xy)"
  adb shell input tap $xy
}

# tap_text <exact text>
#
# Some elements (this app's bottom tab bar: Discovery/Restaurants/Store/
# Search/Profile, confirmed via uiautomator dump) render their label as a
# separate non-clickable child whose bounds collapse to "[0,0][0,0]", while
# the actual tappable parent carries the same string as content-desc
# instead. A tap computed from a [0,0][0,0] box lands on the screen's
# top-left corner, not the element - the tap "succeeds" (adb reports no
# error) but silently does nothing, so the flow times out several steps
# later looking like an unrelated failure. Fall back to content-desc
# before giving up, so every current and future caller gets this for free
# instead of needing to know to use tap_desc for tab-bar-style elements.
tap_text() {
  local text="$1"
  local f; f=$(ui_dump)
  local b; b=$(_bounds_by_text "$text" "$f")
  if [[ -z "$b" || "$b" == "0,0,0,0" ]]; then
    local db; db=$(_bounds_by_desc "$text" "$f")
    if [[ -n "$db" && "$db" != "0,0,0,0" ]]; then
      b="$db"
    fi
  fi
  if [[ -z "$b" || "$b" == "0,0,0,0" ]]; then
    _log "tap_text FAILED - text=\"$text\" not found (or only as a zero-bounds node)"
    return 1
  fi
  local xy; xy=$(_center_of "$b")
  _log "tap text=\"$text\" at ($xy)"
  adb shell input tap $xy
}

# tap_desc <exact content-desc>
tap_desc() {
  local desc="$1"
  local f; f=$(ui_dump)
  local b; b=$(_bounds_by_desc "$desc" "$f")
  if [[ -z "$b" ]]; then
    _log "tap_desc FAILED - content-desc=\"$desc\" not found"
    return 1
  fi
  local xy; xy=$(_center_of "$b")
  _log "tap content-desc=\"$desc\" at ($xy)"
  adb shell input tap $xy
}

# tap_nth_edittext <n> -- taps the Nth (1-indexed) EditText field on
# screen, for login forms whose fields have neither resource-id,
# content-desc, nor stable placeholder text to match on.
tap_nth_edittext() {
  local n="$1"
  local f; f=$(ui_dump)
  local b; b=$(_bounds_by_nth_edittext "$n" "$f")
  if [[ -z "$b" ]]; then
    _log "tap_nth_edittext FAILED - no EditText at position $n"
    return 1
  fi
  local xy; xy=$(_center_of "$b")
  _log "tap EditText #$n at ($xy)"
  adb shell input tap $xy
}

# tap_id_retry <testID> [tries] [waitAfterTapSeconds]
# Retries the tap up to `tries` times - covers the known "first tap after a
# fresh screen sometimes doesn't register" flakiness instead of trusting one tap.
tap_id_retry() {
  local id="$1" tries="${2:-2}" pause="${3:-2}"
  local i=1
  while (( i <= tries )); do
    if tap_id "$id"; then
      sleep "$pause"
      return 0
    fi
    _log "tap_id_retry: attempt $i/$tries failed for id=$id, retrying"
    i=$((i + 1))
    sleep 1
  done
  return 1
}

# tap_text_retry <exact text> [tries] [waitAfterTapSeconds] -- same retry
# behavior as tap_id_retry, for elements only reliably addressable by text
# (e.g. login-form fields whose testID isn't reaching the native view as a
# resource-id on this build - confirmed via uiautomator dump).
tap_text_retry() {
  local text="$1" tries="${2:-2}" pause="${3:-2}"
  local i=1
  while (( i <= tries )); do
    if tap_text "$text"; then
      sleep "$pause"
      return 0
    fi
    _log "tap_text_retry: attempt $i/$tries failed for text=\"$text\", retrying"
    i=$((i + 1))
    sleep 1
  done
  return 1
}

# type_text <text> -- adb's `input text` chokes on literal spaces; escape as %s.
type_text() {
  local text="$1"
  local escaped="${text// /%s}"
  _log "type_text \"$text\""
  adb shell input text "$escaped"
}

# clear_input -- selects all (Ctrl+A) and deletes
clear_input() {
  _log "clearing input"
  adb shell input keycombination 113 29 >/dev/null 2>&1
  adb shell input keyevent 67 >/dev/null 2>&1
}

press_back() {
  _log "press Back"
  adb shell input keyevent 4
}

press_key() {
  _log "press keyevent $1"
  adb shell input keyevent "$1"
}

# force_relaunch <appId> -- am force-stop + relaunch via the launcher category.
force_relaunch() {
  local appId="$1"
  _log "force-stop + relaunch $appId"
  adb shell am force-stop "$appId"
  sleep 1
  adb shell monkey -p "$appId" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

# clean_relaunch <appId> -- pm clear (wipes AsyncStorage/login/cart) + relaunch.
# Use this when a fully deterministic run matters more than saving the login step.
#
# `pm clear` wipes more than app data - it also wipes the Expo dev-client's own
# "last connected Metro server" history, so instead of auto-reconnecting like a
# plain force-stop relaunch does, the app lands on the raw dev-launcher chooser
# screen ("Development Build" / "Recently opened"). ensure_dev_client_connected
# (called by the flow scripts right after this) detects and handles that.
clean_relaunch() {
  local appId="$1"
  _log "pm clear + relaunch $appId"
  adb shell pm clear "$appId" >/dev/null
  sleep 1
  adb shell monkey -p "$appId" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

# ensure_dev_client_connected <metroUrl> [timeoutSeconds] -- polls for up to
# timeout seconds for the Expo dev-launcher chooser screen ("Development
# Build"). Once that header is visible, the recently-opened server list
# (which contains the tappable URL row) populates asynchronously and can lag
# a further several seconds behind the header - so once detected, retry the
# tap itself on its own schedule (every 10s, 5 attempts = 50s) instead of
# giving up after a single miss. Returns 0 immediately if Discovery is
# already visible (dev-client auto-reconnected on its own, chooser skipped).
ensure_dev_client_connected() {
  local url="$1" timeout="${2:-20}" start=$SECONDS

  # Phase 1: wait for either Discovery or the chooser header to show up.
  local seen_chooser=0
  while (( SECONDS - start < timeout )); do
    local f; f=$(ui_dump)
    if grep -q 'text="Discovery"' "$f"; then
      return 0
    fi
    if grep -q 'text="Development Build"' "$f"; then
      seen_chooser=1
      break
    fi
    sleep 2
  done

  if (( seen_chooser == 0 )); then
    _log "ensure_dev_client_connected: never saw the dev-launcher chooser or Discovery within ${timeout}s"
    return 0
  fi

  # Phase 2: chooser header is up, but the server-list row may not have
  # rendered yet - retry the tap every 10s, up to 5 times. Crucially: a tap
  # command reporting success only means adb delivered the touch event, not
  # that navigation actually happened (confirmed - a tap can silently miss
  # if the row isn't truly interactive yet, e.g. still mid ripple-in), so
  # verify we actually left the chooser screen before declaring success.
  local tries=5 interval=10 i=1
  while (( i <= tries )); do
    local f; f=$(ui_dump)
    if grep -q 'text="Discovery"' "$f"; then
      return 0
    fi
    if ! grep -q 'text="Development Build"' "$f"; then
      # Left the chooser screen (e.g. onto a dev-menu overlay or loading
      # screen) even though Discovery isn't up yet - connect succeeded,
      # the rest of the flow's own waits will handle what comes next.
      return 0
    fi
    _log "dev-launcher chooser screen detected, attempt $i/$tries: connecting to $url"
    tap_desc "$url" || tap_text "$url"
    sleep 3
    local f2; f2=$(ui_dump)
    if ! grep -q 'text="Development Build"' "$f2"; then
      _log "left chooser screen after tap - connect succeeded"
      return 0
    fi
    _log "still on chooser screen after tap, waiting $((interval - 3))s before retry"
    sleep "$((interval - 3))"
    i=$((i + 1))
  done

  _log "ensure_dev_client_connected: chooser screen never showed a tappable \"$url\" row after $tries attempts"
  return 1
}

# launch_dev_client <appId> <scheme> <port> -- reverses the port via adb reverse,
# then launches the app directly into its Metro packager URL using the Expo Dev Client's
# registered custom scheme. This bypasses the Dev Launcher chooser screen completely
# and avoids the slow 10.0.2.2 NAT gateway, loading directly via localhost over ADB.
launch_dev_client() {
  local appId="$1"
  local scheme="$2"
  local port="$3"

  _log "reversing port $port for $appId"
  adb reverse "tcp:$port" "tcp:$port" >/dev/null 2>&1

  _log "launching $appId via direct deep link (localhost:$port)"
  adb shell am start -a android.intent.action.VIEW \
    -d "${scheme}://expo-development-client/?url=http%3A%2F%2Flocalhost%3A${port}" \
    "$appId" >/dev/null 2>&1
}

# dismiss_dev_menu [timeoutSeconds] -- dismisses all startup overlays:
# 1. Android native notification-permission dialog ("Allow")
# 2. Emulator "Must use physical device for Push Notifications" alert ("OK")
# 3. Expo dev-client welcome overlay ("Continue")
# 4. Expo dev-client full dev menu ("Reload" + "Go home" -> Back key)
dismiss_dev_menu() {
  local timeout="${1:-12}" start=$SECONDS
  while (( SECONDS - start < timeout )); do
    local f; f=$(ui_dump)

    # 1. Android native notification permission dialog
    if grep -q 'send you notifications' "$f"; then
      _log "notification-permission dialog detected, tapping Allow"
      tap_text "Allow" || true
      sleep 1
      continue
    fi

    # 2. Emulator "Must use physical device for Push Notifications" alert
    if grep -q 'Must use physical device for Push Notifications' "$f"; then
      _log "push notification warning dialog detected, dismissing via OK"
      tap_text "OK" || press_back
      sleep 1
      continue
    fi

    # 3. Dev-menu welcome overlay ("Continue")
    if grep -q 'text="Continue"' "$f"; then
      _log "dev-menu Continue overlay detected, tapping Continue"
      tap_text "Continue" || press_back
      sleep 1
      continue
    fi

    # 4. Dev-menu options overlay ("Reload" and "Go home")
    if grep -q 'text="Reload"' "$f" && grep -q 'text="Go home"' "$f"; then
      _log "dev-menu full overlay detected, dismissing via Back key"
      press_back
      sleep 1
      continue
    fi

    # If app content is showing, done
    if grep -q 'store-login\|customer-login\|Discovery\|Enter Your Credentials\|multivendor' "$f"; then
      _log "app content detected, overlays cleared"
      return 0
    fi

    sleep 1
  done
  return 0
}

# wait_for_stable_screen [timeoutSeconds] -- polls until uiautomator dump
# returns non-trivial content (i.e. the JS bundle has rendered something),
# for use right after a cold launch/relaunch.
wait_for_stable_screen() {
  local timeout="${1:-40}" start=$SECONDS
  while (( SECONDS - start < timeout )); do
    local f; f=$(ui_dump)
    local count
    count=$(grep -o 'text="[^"]\+"' "$f" | wc -l)
    if (( count > 0 )); then
      _log "screen has content after $((SECONDS - start))s (${count} text nodes)"
      return 0
    fi
    sleep 2
  done
  _log "TIMEOUT waiting for stable screen (${timeout}s)"
  return 1
}
