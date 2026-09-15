#!/usr/bin/env bash
# Build a debug APK for one Expo app locally with Gradle — no EAS build
# credits used. Run scripts/build-setup/setup-android.sh once first.
#
# Usage: build-apk.sh <app-dir>
#   e.g. build-apk.sh multivendor-rider
#
# Output: dist/apks/<app-dir>-debug.apk (overwritten on each run)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
ROOT="$(repo_root)"

APP_DIR="${1:-}"
if [ -z "$APP_DIR" ]; then
  err "usage: build-apk.sh <app-dir>"
  exit 1
fi

APP_PATH="$ROOT/$APP_DIR"
if [ ! -d "$APP_PATH" ]; then
  err "app directory not found: $APP_PATH"
  exit 1
fi

# Pick up ANDROID_HOME/JAVA_HOME if this shell hasn't sourced the profile
# script setup-android.sh installed (e.g. a non-login shell in the same
# session that ran setup-android.sh).
if [ -z "${ANDROID_HOME:-}" ] && [ -f /etc/profile.d/android-sdk.sh ]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/android-sdk.sh
fi
if [ -z "${ANDROID_HOME:-}" ] || ! command -v sdkmanager >/dev/null 2>&1; then
  err "Android SDK not found. Run: bash scripts/build-setup/setup-android.sh"
  exit 1
fi

export CI=1 # keep expo prebuild / gradle non-interactive

log "[$APP_DIR] expo prebuild --platform android"
(cd "$APP_PATH" && npx expo prebuild --platform android --clean)

log "[$APP_DIR] chmod +x gradlew"
chmod +x "$APP_PATH/android/gradlew"

log "[$APP_DIR] ./gradlew assembleDebug (this can take a while on first run)"
(cd "$APP_PATH/android" && ./gradlew assembleDebug)

SRC_APK="$APP_PATH/android/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$SRC_APK" ]; then
  err "[$APP_DIR] build finished but $SRC_APK is missing — check gradle output above"
  exit 1
fi

OUT_DIR="$ROOT/dist/apks"
mkdir -p "$OUT_DIR"
OUT_APK="$OUT_DIR/$APP_DIR-debug.apk"
cp "$SRC_APK" "$OUT_APK"

log "[$APP_DIR] built: $OUT_APK ($(du -h "$OUT_APK" | cut -f1))"
log "next: bash scripts/build-setup/serve-apks.sh"
