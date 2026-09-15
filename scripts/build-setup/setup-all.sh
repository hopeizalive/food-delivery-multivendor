#!/usr/bin/env bash
# Entry point for setting up all Expo apps (multivendor-app, -rider, -store)
# in a fresh container — GitHub Codespaces, another devcontainer, or plain CI.
# Installs dependencies and writes each app's .env against the hosted
# demo mock-api. Run scripts/build-setup/verify-build.sh afterwards to
# confirm each app actually builds.
#
# Usage: setup-all.sh [--force] [--api-url <https://host>] [app-dir ...]
#   --force            overwrite existing .env files
#   --api-url <url>    point every app at a different GraphQL/REST host
#                       instead of the hosted mock-api (e.g. a local
#                       mock-api on http://localhost:4000)
#   [app-dir ...]       only set up the named app(s), e.g. multivendor-rider
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

ALL_APPS=(multivendor-app multivendor-rider multivendor-store)

FORCE=0
API_URL=""
APPS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --api-url) API_URL="$2"; shift 2 ;;
    -*) err "unknown flag: $1"; exit 1 ;;
    *) APPS+=("$1"); shift ;;
  esac
done

if [ "${#APPS[@]}" -eq 0 ]; then
  APPS=("${ALL_APPS[@]}")
fi

check_node_version

EXTRA_ARGS=()
[ "$FORCE" -eq 1 ] && EXTRA_ARGS+=(--force)
[ -n "$API_URL" ] && EXTRA_ARGS+=(--api-url "$API_URL")

for app in "${APPS[@]}"; do
  "$SCRIPT_DIR/setup-app.sh" "$app" "${EXTRA_ARGS[@]}"
done

log "all done: ${APPS[*]}"
log "next: bash scripts/build-setup/verify-build.sh"
