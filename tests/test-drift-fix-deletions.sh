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

$SCRIPT_DIR/../scripts/drift-fix.sh >/tmp/drift-fix-deletions.json

! grep -q '`worker.ts`' src/core/AGENTS.md || fail "deleted worker.ts reference still present"
grep -q '`engine.ts`' src/core/AGENTS.md || fail "engine.ts entry should be preserved"
grep -q '`scheduler.ts`' src/core/AGENTS.md || fail "scheduler.ts entry should be preserved"

grep -q '^- `engine.ts`' src/core/AGENTS.md || fail "bullet list format not preserved"
grep -q '^- `scheduler.ts`' src/core/AGENTS.md || fail "bullet list format not preserved after deletion"

echo "PASS: deletions"
