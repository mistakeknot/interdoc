#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"
WORKTREE_DIR="$(mktemp -d)"
trap 'cleanup_test_repo; rm -rf "$WORKTREE_DIR"' EXIT
setup_test_repo
git -C "$TEST_REPO" worktree add -q --detach "$WORKTREE_DIR" HEAD
cd "$WORKTREE_DIR"

OUTPUT="$("$SCRIPT_DIR/../scripts/drift-fix.sh")"
echo "$OUTPUT" | jq -e '.files_modified | length == 3' >/dev/null
grep -q 'src/api/controller.ts' AGENTS.md
grep -q 'src/api/handler.ts' "$TEST_REPO/AGENTS.md"
test -f "$(git rev-parse --git-path interdoc/fix.lock)"
echo "PASS: linked worktree lock and checkout isolation"
