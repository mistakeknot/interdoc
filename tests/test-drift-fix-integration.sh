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

OUTPUT="$($SCRIPT_DIR/../scripts/drift-fix.sh)"

echo "$OUTPUT" | jq -e '
  has("renames") and
  has("deletions") and
  has("new_files") and
  has("links_fixed") and
  has("files_modified")
' >/dev/null || fail "missing required JSON keys"

echo "$OUTPUT" | jq -e '.renames | length == 2' >/dev/null || fail "integration expected 2 renames"
echo "$OUTPUT" | jq -e '.deletions | length == 1' >/dev/null || fail "integration expected 1 deletion"
echo "$OUTPUT" | jq -e '.new_files | length == 1' >/dev/null || fail "integration expected 1 new file"
echo "$OUTPUT" | jq -e '.links_fixed | length == 0' >/dev/null || fail "integration expected 0 link fixes"
echo "$OUTPUT" | jq -e '.files_modified | length == 3' >/dev/null || fail "integration expected 3 modified AGENTS.md files"

echo "$OUTPUT" | jq -e '.files_modified | index("./AGENTS.md") != null' >/dev/null || fail "root AGENTS.md missing from files_modified"
echo "$OUTPUT" | jq -e '.files_modified | index("./src/api/AGENTS.md") != null' >/dev/null || fail "src/api/AGENTS.md missing from files_modified"
echo "$OUTPUT" | jq -e '.files_modified | index("./src/core/AGENTS.md") != null' >/dev/null || fail "src/core/AGENTS.md missing from files_modified"

grep -q 'src/api/controller.ts' AGENTS.md || fail "root AGENTS.md missing controller.ts"
! grep -q 'src/api/handler.ts' AGENTS.md || fail "root AGENTS.md still has handler.ts"

grep -q '`auth.ts`' src/api/AGENTS.md || fail "src/api/AGENTS.md missing auth.ts"
! grep -q '`middleware.ts`' src/api/AGENTS.md || fail "src/api/AGENTS.md still has middleware.ts"

! grep -q '`worker.ts`' src/core/AGENTS.md || fail "src/core/AGENTS.md still has worker.ts"
grep -q '`engine.ts`' src/core/AGENTS.md || fail "src/core/AGENTS.md lost engine.ts unexpectedly"

echo "PASS: integration"
