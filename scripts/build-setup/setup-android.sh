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
JDK_HOME="${JDK_HOME:-$HOME/.jdk21}"
PROFILE_SCRIPT="/etc/profile.d/android-sdk.sh"

# apt on this image's Debian release (bullseye) doesn't carry openjdk-21 —
# it only reached Debian from bookworm onward — so install Eclipse Temurin
# 21 directly from its own release API instead of relying on apt at all.
log "installing JDK 21 (Eclipse Temurin) — ~200MB download, this takes a bit"
if [ ! -x "$JDK_HOME/bin/java" ]; then
  TMP_JDK_TAR="$(mktemp)"
  curl -fSL --progress-bar -o "$TMP_JDK_TAR" \
    "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"
  mkdir -p "$JDK_HOME"
  tar -xzf "$TMP_JDK_TAR" -C "$JDK_HOME" --strip-components=1
  rm -f "$TMP_JDK_TAR"
else
  log "JDK 21 already installed at $JDK_HOME"
fi

if ! command -v unzip >/dev/null 2>&1; then
  log "installing unzip"
  sudo apt-get update -qq
  sudo apt-get install -y -qq unzip
fi

if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "downloading Android command-line tools ($CMDLINE_TOOLS_VERSION)"
  TMP_ZIP="$(mktemp)"
  curl -fSL --progress-bar -o "$TMP_ZIP" \
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

export JAVA_HOME="$JDK_HOME"
export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$JDK_HOME/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

log "accepting SDK licenses (output below is sdkmanager's own — normal, not stuck)"
# `yes` gets SIGPIPE'd once sdkmanager stops reading, and under pipefail
# that alone makes the pipeline report non-zero even when sdkmanager
# itself succeeded -- which would abort the whole script right here (set
# -e) despite licenses actually being accepted. Check sdkmanager's own
# exit code via PIPESTATUS instead of trusting the pipeline's.
if ! yes | sdkmanager --licenses; then
  SDKMANAGER_EXIT="${PIPESTATUS[1]}"
  if [ "$SDKMANAGER_EXIT" -ne 0 ]; then
    err "sdkmanager --licenses failed (exit $SDKMANAGER_EXIT) -- not just yes's harmless SIGPIPE"
    exit 1
  fi
fi
log "installing platform-tools, platforms, build-tools — another few hundred MB, this also takes a bit"
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" "build-tools;36.0.0" \
  "platforms;android-35" "build-tools;35.0.0"

log "writing $PROFILE_SCRIPT so ANDROID_HOME/PATH persist in every new shell"
sudo tee "$PROFILE_SCRIPT" >/dev/null <<EOF
export JAVA_HOME="$JDK_HOME"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="\$JAVA_HOME/bin:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$PATH"
EOF
sudo chmod +x "$PROFILE_SCRIPT"

# /etc/profile.d only auto-loads for a login shell; VS Code's default
# integrated terminal is a non-login shell that only reads ~/.bashrc, so
# source it from there too (idempotent — skips if already added).
BASHRC_MARKER="# android-sdk (scripts/build-setup/setup-android.sh)"
if ! grep -qF "$BASHRC_MARKER" "$HOME/.bashrc" 2>/dev/null; then
  {
    echo "$BASHRC_MARKER"
    echo "[ -f '$PROFILE_SCRIPT' ] && source '$PROFILE_SCRIPT'"
  } >> "$HOME/.bashrc"
fi

log "Android SDK ready at $ANDROID_SDK_ROOT"
log "pick up the env vars now with: source $PROFILE_SCRIPT"
log "(new terminals will get it automatically from now on)"
