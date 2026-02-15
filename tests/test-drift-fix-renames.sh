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

$SCRIPT_DIR/../scripts/drift-fix.sh >/tmp/drift-fix-renames.json

[ -f AGENTS.md ] || fail "root AGENTS.md missing"
[ -f src/api/AGENTS.md ] || fail "src/api/AGENTS.md missing"

grep -q '| File | Purpose |' AGENTS.md || fail "root table format not preserved"
grep -q '| File | Purpose |' src/api/AGENTS.md || fail "api table format not preserved"

grep -q 'src/api/controller.ts' AGENTS.md || fail "full-path rename not applied in root AGENTS.md"
! grep -q 'src/api/handler.ts' AGENTS.md || fail "stale full-path handler.ts remains in root AGENTS.md"

grep -q '`controller.ts`' src/api/AGENTS.md || fail "basename rename to controller.ts not applied"
! grep -q '`handler.ts`' src/api/AGENTS.md || fail "stale basename handler.ts remains"

grep -q '`auth.ts`' src/api/AGENTS.md || fail "basename rename to auth.ts not applied"
! grep -q '`middleware.ts`' src/api/AGENTS.md || fail "stale basename middleware.ts remains"

echo "PASS: renames"
