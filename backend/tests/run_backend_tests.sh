#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8000}"
TOKEN="${FIREBASE_ID_TOKEN:-}"

echo "Running backend smoke tests against: ${BASE_URL}"
python tests/smoke_backend.py --base-url "${BASE_URL}"

if [[ -n "${TOKEN}" ]]; then
  echo
  echo "Running authenticated backend tests..."
  python tests/auth_backend_checks.py --base-url "${BASE_URL}" --token "${TOKEN}"
else
  echo
  echo "Skipping authenticated tests (set FIREBASE_ID_TOKEN env var to enable)."
fi

echo
printf "All requested backend tests completed.\n"
