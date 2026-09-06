#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"
EXTERNAL_DIR="$(mktemp -d)"
trap 'cleanup_test_repo; rm -rf "$EXTERNAL_DIR"' EXIT
setup_test_repo
cd "$TEST_REPO"

git mv src/api src/http
git commit -q -m "test: rename api directory to http"
# A current checkout can replace the renamed destination with an external
# symlink. A historical rename must not redirect documentation outside it.
mv src/http "$EXTERNAL_DIR/http"
ln -s "$EXTERNAL_DIR/http" src/http
cp "$EXTERNAL_DIR/http/AGENTS.md" "$EXTERNAL_DIR/before.md"

OUTPUT="$("$SCRIPT_DIR/../scripts/drift-fix.sh")"
grep -q '(src/api/AGENTS.md)' AGENTS.md
grep -q '(../api/AGENTS.md)' src/core/AGENTS.md
echo "$OUTPUT" | jq -e '.links_fixed | length == 0' >/dev/null
cmp -s "$EXTERNAL_DIR/http/AGENTS.md" "$EXTERNAL_DIR/before.md"
echo "PASS: external symlink destination remains outside repair scope"
