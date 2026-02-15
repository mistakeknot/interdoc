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

git mv src/api src/http
git commit -q -m "test: rename api directory to http"

OUTPUT="$($SCRIPT_DIR/../scripts/drift-fix.sh)"

grep -q 'src/http/AGENTS.md' AGENTS.md || fail "root link src/api/AGENTS.md was not updated"
! grep -q 'src/api/AGENTS.md' AGENTS.md || fail "stale root link to src/api/AGENTS.md remains"

grep -q '../http/AGENTS.md' src/core/AGENTS.md || fail "relative core link ../api/AGENTS.md was not updated"
! grep -q '../api/AGENTS.md' src/core/AGENTS.md || fail "stale relative link ../api/AGENTS.md remains"

echo "$OUTPUT" | jq -e '.links_fixed | length >= 2' >/dev/null || fail "expected at least 2 fixed links in output"
echo "$OUTPUT" | jq -e '.links_fixed[] | select(.old == "src/api/AGENTS.md" and .new == "src/http/AGENTS.md")' >/dev/null || fail "missing root link fix record"
echo "$OUTPUT" | jq -e '.links_fixed[] | select(.old == "../api/AGENTS.md" and .new == "../http/AGENTS.md")' >/dev/null || fail "missing relative link fix record"

echo "PASS: links"
