#!/usr/bin/env bash
# Runs the full rider flow chain (login -> claim -> pickup -> deliver)
# via raw adb shell automation.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

for step in rider/01-login.sh rider/02-claim-order.sh rider/03-pickup-order.sh rider/04-deliver-order.sh; do
  echo "### running $step ###"
  bash "$step"
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "### $step FAILED (exit $status), stopping chain ###"
    exit "$status"
  fi
done

echo "### rider flow chain: ALL PASSED ###"
