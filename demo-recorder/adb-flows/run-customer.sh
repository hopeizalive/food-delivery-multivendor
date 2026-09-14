#!/usr/bin/env bash
# Runs the full customer flow chain (login -> browse -> add-to-cart ->
# checkout -> place-order) via raw adb shell automation. No WSL2, no Maestro.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

for step in customer/01-login.sh customer/02-browse.sh customer/03-add-to-cart.sh customer/04-checkout.sh customer/05-place-order.sh; do
  echo "### running $step ###"
  bash "$step"
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "### $step FAILED (exit $status), stopping chain ###"
    exit "$status"
  fi
done

echo "### customer flow chain: ALL PASSED ###"
