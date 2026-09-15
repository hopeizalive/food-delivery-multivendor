#!/usr/bin/env bash
# One-time install of JDK 21 + the Android SDK pieces needed to build a
# debug APK locally with Gradle (no EAS/cloud build required). Idempotent —
# safe to re-run; skips whatever's already installed.
#
# JDK 21, not 17: matches what the team already builds these apps with
# locally, so Gradle/AGP behavior here matches their known-working setup.
#
# Installs platform android-36 and android-35 + matching build-tools, since
# that covers what multivendor-app/-rider (explicit compileSdkVersion 36 via
# expo-build-properties) and multivendor-store (no override, Expo SDK 53
# default) each need.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

CMDLINE_TOOLS_VERSION="9862592" # matches Google's current repository2-1.xml
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
PROFILE_SCRIPT="/etc/profile.d/android-sdk.sh"

log "installing JDK 21"
if ! java -version 2>&1 | grep -q '"21\.'; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq openjdk-21-jdk
else
  log "JDK 21 already installed"
fi

if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "downloading Android command-line tools ($CMDLINE_TOOLS_VERSION)"
  TMP_ZIP="$(mktemp)"
  curl -fsSL -o "$TMP_ZIP" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  unzip -q "$TMP_ZIP" -d "$ANDROID_SDK_ROOT/cmdline-tools"
  # The zip extracts to cmdline-tools/cmdline-tools; sdkmanager expects .../latest
  mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -f "$TMP_ZIP"
else
  log "Android command-line tools already installed"
fi

JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
export JAVA_HOME
export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

log "accepting SDK licenses + installing platform-tools, platforms, build-tools"
yes | sdkmanager --licenses >/dev/null
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" "build-tools;36.0.0" \
  "platforms;android-35" "build-tools;35.0.0" \
  >/dev/null

log "writing $PROFILE_SCRIPT so ANDROID_HOME/PATH persist in every new shell"
sudo tee "$PROFILE_SCRIPT" >/dev/null <<EOF
export JAVA_HOME="$JAVA_HOME"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$JAVA_HOME/bin:\$PATH"
EOF
sudo chmod +x "$PROFILE_SCRIPT"

log "Android SDK ready at $ANDROID_SDK_ROOT — open a new terminal (or 'source $PROFILE_SCRIPT') to pick up the env vars"
