#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass_count=0
fail_count=0

for test_file in "$SCRIPT_DIR"/test-drift-fix-*.sh; do
  if bash "$test_file"; then
    pass_count=$((pass_count + 1))
  else
    fail_count=$((fail_count + 1))
  fi
done

echo "PASS: $pass_count"
echo "FAIL: $fail_count"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
