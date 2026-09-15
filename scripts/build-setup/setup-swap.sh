#!/usr/bin/env bash
# Best-effort: add a swapfile so a memory spike during an Android build
# slows down instead of getting a process (or the whole container) killed
# outright. Codespaces' free 8GB machine has no swap by default. Safe to
# re-run; does nothing if swap is already active. Never fails the caller —
# if swap can't be set up in this environment, it just warns and returns.
#
# Usage: setup-swap.sh [size-in-GB, default 4]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

SWAP_FILE="/swapfile"
SWAP_SIZE_GB="${1:-4}"

if swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
  log "swap already active: $(swapon --show --noheadings 2>/dev/null)"
  exit 0
fi

log "creating a ${SWAP_SIZE_GB}GB swapfile at $SWAP_FILE (best-effort, needs sudo)"
if ! sudo fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE" 2>/dev/null; then
  if ! sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=none 2>/dev/null; then
    warn "could not allocate $SWAP_FILE (disk space or permissions) — continuing without swap"
    exit 0
  fi
fi

sudo chmod 600 "$SWAP_FILE"
if sudo mkswap "$SWAP_FILE" >/dev/null 2>&1 && sudo swapon "$SWAP_FILE" 2>/dev/null; then
  log "swap enabled: $(swapon --show --noheadings 2>/dev/null)"
else
  warn "swapon failed — this container may not allow enabling swap. Continuing without it."
  sudo rm -f "$SWAP_FILE" 2>/dev/null || true
fi
