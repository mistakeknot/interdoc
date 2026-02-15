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

$SCRIPT_DIR/../scripts/drift-fix.sh >/tmp/drift-fix-idempotent-run1.json

BEFORE_HASHES="$(mktemp)"
AFTER_HASHES="$(mktemp)"

find . -type f -name 'AGENTS.md' -not -path '*/.git/*' | sort | while read -r f; do
  sha256sum "$f"
done > "$BEFORE_HASHES"

SECOND_OUTPUT="$($SCRIPT_DIR/../scripts/drift-fix.sh)"

echo "$SECOND_OUTPUT" | jq -e '.files_modified | length == 0' >/dev/null || fail "files_modified should be empty on second run"

find . -type f -name 'AGENTS.md' -not -path '*/.git/*' | sort | while read -r f; do
  sha256sum "$f"
done > "$AFTER_HASHES"

diff -u "$BEFORE_HASHES" "$AFTER_HASHES" >/dev/null || fail "AGENTS.md content changed on second run"

rm -f "$BEFORE_HASHES" "$AFTER_HASHES"

echo "PASS: idempotent"
