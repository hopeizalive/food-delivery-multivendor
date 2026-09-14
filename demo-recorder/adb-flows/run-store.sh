#!/usr/bin/env bash
# Runs the store flow chain (login -> accept-order) via raw adb shell automation.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

for step in store/01-login.sh store/02-accept-order.sh; do
  echo "### running $step ###"
  bash "$step"
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "### $step FAILED (exit $status), stopping chain ###"
    exit "$status"
  fi
done

echo "### store flow chain: ALL PASSED ###"
