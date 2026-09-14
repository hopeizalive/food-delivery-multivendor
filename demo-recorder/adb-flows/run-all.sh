#!/usr/bin/env bash
# Runs the full three-app lifecycle chain:
# 1. Customer places order (login -> browse -> add-to-cart -> checkout -> place-order)
# 2. Store accepts order (login -> accept-order)
# 3. Rider delivers order (login -> claim -> pickup -> deliver)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

echo "=========================================="
echo "RESETTING DEMO STATE (clean slate)"
echo "=========================================="
curl -s -X POST http://localhost:4000/graphql -H "Content-Type: application/json" -d '{"query":"mutation{ resetDemo }"}' >/dev/null 2>&1 || true
sleep 1

echo "=========================================="
echo "STAGE 1: CUSTOMER FLOW"
echo "=========================================="
bash run-customer.sh || { echo "Customer flow failed"; exit 1; }

echo "=========================================="
echo "STAGE 2: STORE FLOW"
echo "=========================================="
bash run-store.sh || { echo "Store flow failed"; exit 1; }

echo "=========================================="
echo "STAGE 3: RIDER FLOW"
echo "=========================================="
bash run-rider.sh || { echo "Rider flow failed"; exit 1; }

echo "=========================================="
echo "ALL FLOWS PASSED: FULL LIFECYCLE COMPLETE!"
echo "=========================================="
