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

# Also cap the Kotlin compiler daemon (a separate JVM Gradle spawns for
# Kotlin sources) — GRADLE_OPTS/--max-workers below don't reach it, only a
# gradle.properties key does. User-home gradle.properties applies to every
# app, so this only needs writing once.
GRADLE_USER_PROPS="$HOME/.gradle/gradle.properties"
mkdir -p "$HOME/.gradle"
if ! grep -q "kotlin.daemon.jvm.options" "$GRADLE_USER_PROPS" 2>/dev/null; then
  echo "kotlin.daemon.jvm.options=-Xmx1g" >> "$GRADLE_USER_PROPS"
fi

log "[$APP_DIR] expo prebuild --platform android"
(cd "$APP_PATH" && npx expo prebuild --platform android --clean)

log "[$APP_DIR] chmod +x gradlew"
chmod +x "$APP_PATH/android/gradlew"

# Codespaces' free machine is 2 cores / 8GB RAM. Gradle's own default heap
# sizing (and a template gradle.properties that assumes a bigger box) plus
# a separate Kotlin-daemon JVM can add up past that and get the whole
# container OOM-killed mid-build -- which looks like "the codespace just
# stopped" with no error, since the kill happens outside the build's own
# process. Keep everything to one JVM, capped, instead of Gradle's
# defaults. GRADLE_OPTS/--no-daemon/--max-workers are honored directly by
# the gradlew launcher regardless of what expo prebuild wrote into the
# regenerated android/gradle.properties.
export GRADLE_OPTS="-Xmx3g -XX:MaxMetaspaceSize=512m"
GRADLE_MEMORY_FLAGS=(--no-daemon --max-workers=2)

log "[$APP_DIR] ./gradlew assembleDebug (this can take a while on first run)"
(cd "$APP_PATH/android" && ./gradlew assembleDebug "${GRADLE_MEMORY_FLAGS[@]}")

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
