#!/usr/bin/env bash
# Verify the local Android toolchain (installed by setup-android.sh) is
# actually usable before running build-apk.sh — checks real files on disk,
# not just "the installer said it finished".
#
# Usage: verify-android.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

PROFILE_SCRIPT="/etc/profile.d/android-sdk.sh"
if [ -z "${ANDROID_HOME:-}" ] && [ -f "$PROFILE_SCRIPT" ]; then
  # shellcheck disable=SC1091
  source "$PROFILE_SCRIPT"
fi

FAILED=()

pass() { log "OK   $1"; }
fail() { err "FAIL $1"; FAILED+=("$1"); }

# JDK 21
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  VERSION_STR="$("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
  if echo "$VERSION_STR" | grep -q '"21\.'; then
    pass "JDK 21 -- $VERSION_STR"
  else
    fail "JAVA_HOME points at a non-21 JDK -- $VERSION_STR"
  fi
else
  fail "JAVA_HOME not set or \$JAVA_HOME/bin/java missing"
fi

# sdkmanager
if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  pass "sdkmanager present"
else
  fail "sdkmanager missing (ANDROID_HOME=${ANDROID_HOME:-<unset>})"
fi

# adb / platform-tools
if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
  pass "adb present"
else
  fail "adb / platform-tools missing"
fi

# platforms
for p in android-36 android-35; do
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/platforms/$p" ]; then
    pass "platform $p installed"
  else
    fail "platform $p missing"
  fi
done

# build-tools
for b in 36.0.0 35.0.0; do
  if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/build-tools/$b/aapt2" ]; then
    pass "build-tools $b installed"
  else
    fail "build-tools $b missing"
  fi
done

# licenses
if [ -n "${ANDROID_HOME:-}" ] && [ -f "$ANDROID_HOME/licenses/android-sdk-license" ]; then
  pass "SDK licenses accepted"
else
  fail "SDK licenses not accepted"
fi

echo
if [ "${#FAILED[@]}" -eq 0 ]; then
  log "Android toolchain looks good. Ready for: bash scripts/build-setup/build-apk.sh <app-dir>"
  exit 0
else
  err "problems found: ${FAILED[*]}"
  err "re-run: bash scripts/build-setup/setup-android.sh"
  exit 1
fi
