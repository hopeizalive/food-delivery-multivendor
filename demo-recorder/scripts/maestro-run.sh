#!/usr/bin/env bash
# Runs inside WSL2 Ubuntu. Wires up Maestro + adb so it can reach the
# Windows-hosted emulator (WSL2 mirrored networking), then runs `maestro test`
# against the flow path(s) given as arguments (relative to demo-recorder/).
#
# Usage (from Windows, via wsl.exe):
#   wsl -d Ubuntu -- bash demo-recorder/scripts/maestro-run.sh flows/rider/01-login.yaml
#
# Confirmed working this session: `maestro --version` -> 2.10.0,
# `adb devices` (via ADB_SERVER_SOCKET) -> emulator-5554 visible.
set -euo pipefail

export PATH="$PATH:$HOME/.maestro/bin"
export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_RECORDER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DEMO_RECORDER_DIR"

if [ "$#" -eq 0 ]; then
  echo "usage: maestro-run.sh <flow.yaml> [more flows...]" >&2
  exit 1
fi

maestro test "$@"
