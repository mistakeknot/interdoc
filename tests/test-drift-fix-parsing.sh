#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

fail() {
  echo "FAIL: $1"
  cleanup_test_repo
  exit 1
}

trap cleanup_test_repo EXIT

setup_test_repo
cd "$TEST_REPO"

OUTPUT="$($SCRIPT_DIR/../scripts/drift-fix.sh --dry-run)"

echo "$OUTPUT" | jq -e '.renames | length == 2' >/dev/null || fail "expected 2 renames"
echo "$OUTPUT" | jq -e '.renames[] | select(.old == "src/api/handler.ts" and .new == "src/api/controller.ts")' >/dev/null || fail "missing handler->controller rename"
echo "$OUTPUT" | jq -e '.renames[] | select(.old == "src/api/middleware.ts" and .new == "src/api/auth.ts")' >/dev/null || fail "missing middleware->auth rename"

echo "$OUTPUT" | jq -e '.deletions | length == 1' >/dev/null || fail "expected 1 deletion"
echo "$OUTPUT" | jq -e '.deletions[0] == "src/core/worker.ts"' >/dev/null || fail "missing worker.ts deletion"

echo "$OUTPUT" | jq -e '.new_files | length == 1' >/dev/null || fail "expected 1 new file"
echo "$OUTPUT" | jq -e '.new_files[0] == "src/core/cache.ts"' >/dev/null || fail "missing cache.ts addition"

echo "PASS: parsing"
