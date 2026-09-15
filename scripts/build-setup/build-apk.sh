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

# Best-effort swapfile so a memory spike degrades (slower) instead of
# Gradle's own low-memory daemon-suicide check killing the build, or the
# OS OOM-killer taking something out. Never fails the build if it can't.
bash "$SCRIPT_DIR/setup-swap.sh" || true

# Also cap the Kotlin compiler daemon (a separate JVM) and force serial
# execution at the properties level too, as a backstop in case a project-
# level gradle.properties (regenerated fresh by expo prebuild --clean
# every run) sets org.gradle.parallel=true and it takes precedence for
# that key over the --max-workers CLI flag. User-home gradle.properties
# applies to every app. Replace-or-append per key so re-running with an
# updated cap actually takes effect instead of leaving a stale value.
GRADLE_USER_PROPS="$HOME/.gradle/gradle.properties"
mkdir -p "$HOME/.gradle"
touch "$GRADLE_USER_PROPS"
grep -vE "^(kotlin\.daemon\.jvm\.options|org\.gradle\.parallel|org\.gradle\.workers\.max)=" \
  "$GRADLE_USER_PROPS" > "$GRADLE_USER_PROPS.tmp" || true
{
  echo "kotlin.daemon.jvm.options=-Xmx768m"
  echo "org.gradle.parallel=false"
  echo "org.gradle.workers.max=1"
} >> "$GRADLE_USER_PROPS.tmp"
mv "$GRADLE_USER_PROPS.tmp" "$GRADLE_USER_PROPS"

log "[$APP_DIR] expo prebuild --platform android"
(cd "$APP_PATH" && npx expo prebuild --platform android --clean)

log "[$APP_DIR] chmod +x gradlew"
chmod +x "$APP_PATH/android/gradlew"

# Codespaces' free machine is 2 cores / 8GB RAM, shared with whatever else
# is running (VS Code server, any Metro dev servers left up from
# start-app.sh, etc). Gradle's own default heap sizing (and a template
# gradle.properties that assumes a bigger box) plus a separate
# Kotlin-daemon JVM can add up past what's left and get the daemon killed
# mid-build (Gradle's own low-memory self-check, or the OS OOM-killer) --
# which looks like "the codespace just stopped"/"daemon disappeared" with
# no real build error. --max-workers=1 (not 2) matters beyond just task
# concurrency: AAPT2 runs its own separate worker-process pool for
# resource/manifest compilation, sized off Gradle's own parallelism
# setting, and that pool isn't bounded by GRADLE_OPTS at all -- on an app
# with many native modules (e.g. multivendor-app's Firebase/Stripe/Sentry/
# Google-Sign-In stack), several concurrent AAPT2 workers alone can tip an
# 8GB box over, surfacing as "AAPT Process manager cannot be shut down
# while daemons are in use" / "the daemon has disappeared". Fully serial
# is slower but safe. GRADLE_OPTS/--no-daemon/--max-workers are honored
# directly by the gradlew launcher regardless of what expo prebuild wrote
# into the regenerated android/gradle.properties. If this still gets
# killed, close any other terminals running `expo start`/Metro first --
# they're competing for the same 8GB.
export GRADLE_OPTS="-Xmx2g -XX:MaxMetaspaceSize=384m"
GRADLE_MEMORY_FLAGS=(--no-daemon --max-workers=1)

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
