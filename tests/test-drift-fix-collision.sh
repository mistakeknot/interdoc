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

# Build a repo with same basename (utils.ts) in two directories
TEST_REPO=$(mktemp -d)
export TEST_REPO

git -C "$TEST_REPO" init -q
git -C "$TEST_REPO" config user.email "test@test.com"
git -C "$TEST_REPO" config user.name "Test User"

mkdir -p "$TEST_REPO/src/api" "$TEST_REPO/src/core"

cat > "$TEST_REPO/src/api/utils.ts" <<'EOF'
export const apiUtils = {};
EOF

cat > "$TEST_REPO/src/core/utils.ts" <<'EOF'
export const coreUtils = {};
EOF

cat > "$TEST_REPO/src/api/AGENTS.md" <<'AGENTS'
# API AGENTS

## Key Files

| File | Purpose |
|------|---------|
| `utils.ts` | API utilities |
AGENTS

cat > "$TEST_REPO/src/core/AGENTS.md" <<'AGENTS'
# Core AGENTS

## Key Files

- `utils.ts` — Core utilities
AGENTS

cat > "$TEST_REPO/AGENTS.md" <<'AGENTS'
# Root AGENTS

## Key Files

| File | Purpose |
|------|---------|
| `src/api/utils.ts` | API utilities |
| `src/core/utils.ts` | Core utilities |
AGENTS

git -C "$TEST_REPO" add -A
git -C "$TEST_REPO" commit -q -m "initial: two utils.ts files"

# Rename only the API utils.ts — core should be untouched
git -C "$TEST_REPO" mv src/api/utils.ts src/api/helpers.ts
git -C "$TEST_REPO" commit -q -m "rename api utils to helpers"

cd "$TEST_REPO"

$SCRIPT_DIR/../scripts/drift-fix.sh >/dev/null

# API AGENTS.md should have the basename replaced (same directory)
grep -q '`helpers.ts`' src/api/AGENTS.md || fail "API AGENTS.md should have helpers.ts"
! grep -q '`utils.ts`' src/api/AGENTS.md || fail "API AGENTS.md still has stale utils.ts"

# Core AGENTS.md should be UNTOUCHED — its utils.ts is a different file
grep -q '`utils.ts`' src/core/AGENTS.md || fail "Core AGENTS.md lost its utils.ts (basename collision)"
! grep -q '`helpers.ts`' src/core/AGENTS.md || fail "Core AGENTS.md incorrectly got helpers.ts"

# Root AGENTS.md should update the full path only
grep -q 'src/api/helpers.ts' AGENTS.md || fail "Root AGENTS.md should have src/api/helpers.ts"
grep -q 'src/core/utils.ts' AGENTS.md || fail "Root AGENTS.md lost src/core/utils.ts"

echo "PASS: collision"
