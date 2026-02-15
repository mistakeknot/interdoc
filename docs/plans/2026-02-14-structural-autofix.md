# Structural Auto-Fix Implementation Plan
**Phase:** executing (as of 2026-02-15T03:39:51Z)

> **For Claude:** REQUIRED SUB-SKILL: Use clavain:executing-plans to implement this plan task-by-task.

**Goal:** Build a deterministic shell script (`drift-fix.sh`) that updates stale AGENTS.md file references (renames, deletions, additions) using git history — no LLM tokens — plus a `/interdoc fix` skill mode to invoke it.

**Architecture:** Two deliverables: (1) `scripts/drift-fix.sh` — a self-contained shell script that reads git history, cross-references AGENTS.md files, and applies structural fixes with atomic writes, and (2) SKILL.md additions for a new "Fix" mode triggered by `/interdoc fix`. The script uses `flock` for concurrency safety and outputs JSON summaries. It never reads from Interwatch or any external state — git-native only.

**Tech Stack:** Bash, sed, grep, jq, flock, git

**PRD:** `docs/prds/2026-02-14-structural-autofix.md` (bead: iv-i82)

---

## Task 1: Create Test Fixtures

Set up a temporary git repo with AGENTS.md files to test `drift-fix.sh` against. These fixtures simulate the exact scenarios: file renames, deletions, additions, and cross-AGENTS.md links.

**Files:**
- Create: `tests/fixtures/setup-test-repo.sh`

**Step 1: Write the test fixture setup script**

```bash
#!/bin/bash
# Sets up a temporary git repo with AGENTS.md files for testing drift-fix.sh
# Usage: source tests/fixtures/setup-test-repo.sh
#        setup_test_repo   # creates repo, returns path in $TEST_REPO
#        cleanup_test_repo # removes it

set -euo pipefail

setup_test_repo() {
    TEST_REPO=$(mktemp -d)
    export TEST_REPO

    cd "$TEST_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create initial structure with AGENTS.md files
    mkdir -p src/api src/core lib

    cat > AGENTS.md << 'AGENTS'
# Root AGENTS.md

## Key Files

| File | Purpose |
|------|---------|
| `src/api/handler.ts` | API request handler |
| `src/core/engine.ts` | Core game engine |
| `lib/utils.ts` | Shared utilities |

## Architecture

See [API docs](src/api/AGENTS.md) and [Core docs](src/core/AGENTS.md).
AGENTS

    cat > src/api/AGENTS.md << 'AGENTS'
# API Layer

## Key Files

| File | Purpose |
|------|---------|
| `handler.ts` | Request handler |
| `middleware.ts` | Auth middleware |
| `routes.ts` | Route definitions |

## Related

- See [Core docs](../core/AGENTS.md) for engine details.
AGENTS

    cat > src/core/AGENTS.md << 'AGENTS'
# Core Engine

## Key Files

- `engine.ts` — Main simulation engine
- `scheduler.ts` — Task scheduler
- `worker.ts` — Worker pool implementation

## Related

- See [API docs](../api/AGENTS.md) for HTTP layer.
AGENTS

    # Create the source files referenced
    echo "// handler" > src/api/handler.ts
    echo "// middleware" > src/api/middleware.ts
    echo "// routes" > src/api/routes.ts
    echo "// engine" > src/core/engine.ts
    echo "// scheduler" > src/core/scheduler.ts
    echo "// worker" > src/core/worker.ts
    echo "// utils" > lib/utils.ts

    git add -A && git commit -q -m "Initial commit with AGENTS.md files"

    # Now simulate changes that cause drift:

    # 1. Rename: handler.ts -> controller.ts
    git mv src/api/handler.ts src/api/controller.ts
    git commit -q -m "Rename handler to controller"

    # 2. Delete: worker.ts
    git rm -q src/core/worker.ts
    git commit -q -m "Remove worker pool"

    # 3. Add: new file
    echo "// cache" > src/core/cache.ts
    git add src/core/cache.ts
    git commit -q -m "Add caching layer"

    # 4. Rename: middleware.ts -> auth.ts
    git mv src/api/middleware.ts src/api/auth.ts
    git commit -q -m "Rename middleware to auth"

    cd - > /dev/null
}

cleanup_test_repo() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
        unset TEST_REPO
    fi
}
```

**Step 2: Run to verify the fixture creates correctly**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash -c 'source tests/fixtures/setup-test-repo.sh && setup_test_repo && echo "Repo at: $TEST_REPO" && cd "$TEST_REPO" && git log --oneline && echo "---" && cat AGENTS.md && echo "---" && cat src/api/AGENTS.md && echo "---" && cat src/core/AGENTS.md && cleanup_test_repo && echo "PASS"'`

Expected: 4 commits shown, all 3 AGENTS.md files printed with stale references, "PASS" at end.

**Step 3: Commit**

```bash
git add tests/fixtures/setup-test-repo.sh
git commit -m "test: add drift-fix test fixtures with rename/delete/add scenarios"
```

---

## Task 2: Create `drift-fix.sh` — Git Diff Parsing

Build the first section of the script: parse git history to find renames, deletions, and additions since the last AGENTS.md update.

**Files:**
- Create: `scripts/drift-fix.sh`

**Step 1: Write the failing test**

Create a test runner that verifies git diff parsing output:

```bash
# tests/test-drift-fix-parsing.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

setup_test_repo
cd "$TEST_REPO"

# Run drift-fix.sh in dry-run/parse-only mode
OUTPUT=$(bash "$SCRIPT_DIR/../scripts/drift-fix.sh" --dry-run 2>/dev/null)

# Verify renames detected
echo "$OUTPUT" | jq -e '.renames | length == 2' > /dev/null || { echo "FAIL: expected 2 renames"; echo "$OUTPUT" | jq '.renames'; exit 1; }
echo "$OUTPUT" | jq -e '.renames[] | select(.old == "src/api/handler.ts" and .new == "src/api/controller.ts")' > /dev/null || { echo "FAIL: handler->controller rename not found"; exit 1; }
echo "$OUTPUT" | jq -e '.renames[] | select(.old == "src/api/middleware.ts" and .new == "src/api/auth.ts")' > /dev/null || { echo "FAIL: middleware->auth rename not found"; exit 1; }

# Verify deletions detected
echo "$OUTPUT" | jq -e '.deletions | length == 1' > /dev/null || { echo "FAIL: expected 1 deletion"; echo "$OUTPUT" | jq '.deletions'; exit 1; }
echo "$OUTPUT" | jq -e '.deletions[0] == "src/core/worker.ts"' > /dev/null || { echo "FAIL: worker.ts deletion not found"; exit 1; }

# Verify additions detected
echo "$OUTPUT" | jq -e '.new_files | length == 1' > /dev/null || { echo "FAIL: expected 1 addition"; echo "$OUTPUT" | jq '.new_files'; exit 1; }
echo "$OUTPUT" | jq -e '.new_files[0] == "src/core/cache.ts"' > /dev/null || { echo "FAIL: cache.ts addition not found"; exit 1; }

cd - > /dev/null
cleanup_test_repo
echo "PASS: git diff parsing"
```

**Step 2: Run test to verify it fails**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-parsing.sh`
Expected: FAIL (drift-fix.sh doesn't exist yet)

**Step 3: Write the script skeleton with git diff parsing**

```bash
#!/bin/bash
# drift-fix.sh — Deterministic structural auto-fix for AGENTS.md files
#
# Reads git history to find file renames, deletions, and additions,
# then updates AGENTS.md references in-place.
#
# Usage: drift-fix.sh [--dry-run]
#   --dry-run  Output JSON summary without modifying files

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

# Must be in a git repo
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo '{"error":"not a git repository"}'; exit 1; }
cd "$REPO_ROOT"

# Find all AGENTS.md files
mapfile -t AGENTS_FILES < <(find . -name "AGENTS.md" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" | sort)

if [ ${#AGENTS_FILES[@]} -eq 0 ]; then
    echo '{"renames":[],"deletions":[],"new_files":[],"links_fixed":[],"files_modified":[]}'
    exit 0
fi

# Find the oldest AGENTS.md last-modified commit
OLDEST_AGENTS_COMMIT=""
for f in "${AGENTS_FILES[@]}"; do
    COMMIT=$(git log -1 --format=%H -- "$f" 2>/dev/null) || continue
    if [ -z "$OLDEST_AGENTS_COMMIT" ]; then
        OLDEST_AGENTS_COMMIT="$COMMIT"
    else
        # Check if this commit is older
        if git merge-base --is-ancestor "$COMMIT" "$OLDEST_AGENTS_COMMIT" 2>/dev/null; then
            OLDEST_AGENTS_COMMIT="$COMMIT"
        fi
    fi
done

if [ -z "$OLDEST_AGENTS_COMMIT" ]; then
    echo '{"renames":[],"deletions":[],"new_files":[],"links_fixed":[],"files_modified":[]}'
    exit 0
fi

# Collect renames since oldest AGENTS.md update
# Format: R100\told_name\tnew_name (or R###\told\tnew for partial matches)
RENAMES_JSON="[]"
while IFS=$'\t' read -r status old_path new_path; do
    [ -z "$old_path" ] && continue
    RENAMES_JSON=$(echo "$RENAMES_JSON" | jq --arg old "$old_path" --arg new "$new_path" '. + [{"old": $old, "new": $new}]')
done < <(git log --diff-filter=R -M --name-status "$OLDEST_AGENTS_COMMIT"..HEAD -- . ':!*.md' 2>/dev/null | grep -E '^R[0-9]+' | sed 's/^R[0-9]*\t//')

# Collect deletions since oldest AGENTS.md update
DELETIONS_JSON="[]"
while IFS= read -r deleted_path; do
    [ -z "$deleted_path" ] && continue
    DELETIONS_JSON=$(echo "$DELETIONS_JSON" | jq --arg path "$deleted_path" '. + [$path]')
done < <(git log --diff-filter=D --name-only --format="" "$OLDEST_AGENTS_COMMIT"..HEAD -- . ':!*.md' 2>/dev/null | sort -u)

# Collect additions since oldest AGENTS.md update
NEW_FILES_JSON="[]"
while IFS= read -r added_path; do
    [ -z "$added_path" ] && continue
    NEW_FILES_JSON=$(echo "$NEW_FILES_JSON" | jq --arg path "$added_path" '. + [$path]')
done < <(git log --diff-filter=A --name-only --format="" "$OLDEST_AGENTS_COMMIT"..HEAD -- . ':!*.md' 2>/dev/null | sort -u)

# Output parse results (--dry-run stops here before applying fixes)
SUMMARY=$(jq -n \
    --argjson renames "$RENAMES_JSON" \
    --argjson deletions "$DELETIONS_JSON" \
    --argjson new_files "$NEW_FILES_JSON" \
    '{renames: $renames, deletions: $deletions, new_files: $new_files, links_fixed: [], files_modified: []}')

if [ "$DRY_RUN" = true ]; then
    echo "$SUMMARY"
    exit 0
fi

echo "$SUMMARY"
```

**Step 4: Run test to verify it passes**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-parsing.sh`
Expected: `PASS: git diff parsing`

**Step 5: Commit**

```bash
git add scripts/drift-fix.sh tests/test-drift-fix-parsing.sh
git commit -m "feat: drift-fix.sh skeleton with git diff parsing for renames, deletions, additions"
```

---

## Task 3: Add Rename Fixing to `drift-fix.sh`

Extend the script to find and replace renamed file references in AGENTS.md files. Handles both markdown table rows (`| file | desc |`) and bullet list items (`- file — desc`).

**Files:**
- Modify: `scripts/drift-fix.sh`
- Create: `tests/test-drift-fix-renames.sh`

**Step 1: Write the failing test**

```bash
# tests/test-drift-fix-renames.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

setup_test_repo
cd "$TEST_REPO"

# Run drift-fix.sh (not dry-run — apply fixes)
bash "$SCRIPT_DIR/../scripts/drift-fix.sh" > /dev/null 2>&1

# Check root AGENTS.md: handler.ts should be replaced with controller.ts
grep -q "controller.ts" AGENTS.md || { echo "FAIL: root AGENTS.md still has handler.ts, not controller.ts"; cat AGENTS.md; exit 1; }
! grep -q "handler.ts" AGENTS.md || { echo "FAIL: root AGENTS.md still mentions handler.ts"; exit 1; }

# Check src/api/AGENTS.md: handler.ts -> controller.ts, middleware.ts -> auth.ts
grep -q "controller.ts" src/api/AGENTS.md || { echo "FAIL: api AGENTS.md missing controller.ts"; exit 1; }
! grep -q "handler.ts" src/api/AGENTS.md || { echo "FAIL: api AGENTS.md still mentions handler.ts"; exit 1; }
grep -q "auth.ts" src/api/AGENTS.md || { echo "FAIL: api AGENTS.md missing auth.ts"; exit 1; }
! grep -q "middleware.ts" src/api/AGENTS.md || { echo "FAIL: api AGENTS.md still mentions middleware.ts"; exit 1; }

# Verify table format preserved in root AGENTS.md
grep -qE '^\| `src/api/controller.ts` \|' AGENTS.md || { echo "FAIL: table format broken in root AGENTS.md"; grep controller AGENTS.md; exit 1; }

# Verify table format preserved in api AGENTS.md
grep -qE '^\| `controller.ts` \|' src/api/AGENTS.md || { echo "FAIL: table format broken in api AGENTS.md"; grep controller src/api/AGENTS.md; exit 1; }

cd - > /dev/null
cleanup_test_repo
echo "PASS: rename fixing"
```

**Step 2: Run test to verify it fails**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-renames.sh`
Expected: FAIL (drift-fix.sh doesn't apply fixes yet)

**Step 3: Add rename-fixing logic to `drift-fix.sh`**

Add this section after the `if [ "$DRY_RUN" = true ]` block in `scripts/drift-fix.sh`, replacing the final `echo "$SUMMARY"`:

```bash
# --- Apply fixes ---

LOCK_DIR=".git/interdoc"
mkdir -p "$LOCK_DIR"

# Acquire exclusive lock
exec 9>"$LOCK_DIR/fix.lock"
flock -n 9 || { echo '{"error":"another drift-fix instance is running"}' >&2; exit 1; }

FILES_MODIFIED_JSON="[]"
LINKS_FIXED_JSON="[]"

# --- Rename fixes ---
# For each rename, find and replace in all AGENTS.md files
for rename_entry in $(echo "$RENAMES_JSON" | jq -c '.[]'); do
    OLD_PATH=$(echo "$rename_entry" | jq -r '.old')
    NEW_PATH=$(echo "$rename_entry" | jq -r '.new')
    OLD_BASENAME=$(basename "$OLD_PATH")
    NEW_BASENAME=$(basename "$NEW_PATH")

    for agents_file in "${AGENTS_FILES[@]}"; do
        # Get the directory of this AGENTS.md for relative path resolution
        AGENTS_DIR=$(dirname "$agents_file")

        # Try full path match first, then basename match
        MODIFIED=false

        # Full relative path (as seen from repo root): src/api/handler.ts
        if grep -qF "$OLD_PATH" "$agents_file" 2>/dev/null; then
            # Atomic write: copy to temp, sed, mv back
            TMP_FILE=$(mktemp "${agents_file}.XXXXXX")
            sed "s|$OLD_PATH|$NEW_PATH|g" "$agents_file" > "$TMP_FILE"
            mv "$TMP_FILE" "$agents_file"
            MODIFIED=true
        fi

        # Basename only (for AGENTS.md in the same directory): handler.ts
        # Only if the AGENTS.md is in the same directory as the renamed file
        OLD_DIR=$(dirname "$OLD_PATH")
        if [ "$AGENTS_DIR" = "./$OLD_DIR" ] || [ "$AGENTS_DIR" = "$OLD_DIR" ]; then
            if grep -qF "$OLD_BASENAME" "$agents_file" 2>/dev/null; then
                TMP_FILE=$(mktemp "${agents_file}.XXXXXX")
                sed "s|$OLD_BASENAME|$NEW_BASENAME|g" "$agents_file" > "$TMP_FILE"
                mv "$TMP_FILE" "$agents_file"
                MODIFIED=true
            fi
        fi

        if [ "$MODIFIED" = true ]; then
            FILES_MODIFIED_JSON=$(echo "$FILES_MODIFIED_JSON" | jq --arg f "$agents_file" 'if (. | index($f)) then . else . + [$f] end')
        fi
    done
done

# Output final summary
jq -n \
    --argjson renames "$RENAMES_JSON" \
    --argjson deletions "$DELETIONS_JSON" \
    --argjson new_files "$NEW_FILES_JSON" \
    --argjson links_fixed "$LINKS_FIXED_JSON" \
    --argjson files_modified "$FILES_MODIFIED_JSON" \
    '{renames: $renames, deletions: $deletions, new_files: $new_files, links_fixed: $links_fixed, files_modified: $files_modified}'
```

**Step 4: Run test to verify it passes**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-renames.sh`
Expected: `PASS: rename fixing`

**Step 5: Commit**

```bash
git add scripts/drift-fix.sh tests/test-drift-fix-renames.sh
git commit -m "feat: drift-fix.sh applies rename fixes to AGENTS.md files with atomic writes"
```

---

## Task 4: Add Deletion Fixing to `drift-fix.sh`

Remove references to deleted files from AGENTS.md. Handles markdown table rows and bullet list items.

**Files:**
- Modify: `scripts/drift-fix.sh`
- Create: `tests/test-drift-fix-deletions.sh`

**Step 1: Write the failing test**

```bash
# tests/test-drift-fix-deletions.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

setup_test_repo
cd "$TEST_REPO"

bash "$SCRIPT_DIR/../scripts/drift-fix.sh" > /dev/null 2>&1

# Check src/core/AGENTS.md: worker.ts line should be removed
! grep -q "worker.ts" src/core/AGENTS.md || { echo "FAIL: core AGENTS.md still mentions worker.ts"; cat src/core/AGENTS.md; exit 1; }

# Verify other entries still exist
grep -q "engine.ts" src/core/AGENTS.md || { echo "FAIL: engine.ts was incorrectly removed"; exit 1; }
grep -q "scheduler.ts" src/core/AGENTS.md || { echo "FAIL: scheduler.ts was incorrectly removed"; exit 1; }

# Verify the bullet list format is preserved (not corrupted)
grep -qE '^- `engine.ts` — ' src/core/AGENTS.md || { echo "FAIL: bullet format broken"; cat src/core/AGENTS.md; exit 1; }

cd - > /dev/null
cleanup_test_repo
echo "PASS: deletion fixing"
```

**Step 2: Run test to verify it fails**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-deletions.sh`
Expected: FAIL (deletions not handled yet)

**Step 3: Add deletion-fixing logic to `drift-fix.sh`**

Insert after the rename fixes section, before the final `jq -n` output:

```bash
# --- Deletion fixes ---
# Remove lines referencing deleted files from AGENTS.md
for deleted_path in $(echo "$DELETIONS_JSON" | jq -r '.[]'); do
    DELETED_BASENAME=$(basename "$deleted_path")

    for agents_file in "${AGENTS_FILES[@]}"; do
        AGENTS_DIR=$(dirname "$agents_file")
        MODIFIED=false

        # Match table rows: | `file` | desc |  or  | file | desc |
        # Match bullet items: - `file` — desc  or  - file — desc
        # Also match: - `path/to/file` — desc
        # We match on both full path and basename

        TMP_FILE=$(mktemp "${agents_file}.XXXXXX")

        # Remove lines containing the deleted file reference
        # Table row pattern: line starts with | and contains the filename
        # Bullet pattern: line starts with - and contains the filename
        grep -v -F "$deleted_path" "$agents_file" | grep -v -F "$DELETED_BASENAME" > "$TMP_FILE" 2>/dev/null || true

        # Check if we actually removed anything
        if ! diff -q "$agents_file" "$TMP_FILE" > /dev/null 2>&1; then
            # Verify we only removed table/bullet lines, not arbitrary content
            # Re-do with more precise matching
            rm -f "$TMP_FILE"
            TMP_FILE=$(mktemp "${agents_file}.XXXXXX")

            while IFS= read -r line; do
                SKIP=false
                # Check if line is a table row or bullet item referencing deleted file
                if echo "$line" | grep -qE '^\|.*'"$DELETED_BASENAME"'.*\|' 2>/dev/null; then
                    SKIP=true
                elif echo "$line" | grep -qE '^- .*'"$DELETED_BASENAME"'' 2>/dev/null; then
                    SKIP=true
                fi
                if [ "$SKIP" = false ]; then
                    echo "$line"
                fi
            done < "$agents_file" > "$TMP_FILE"

            if ! diff -q "$agents_file" "$TMP_FILE" > /dev/null 2>&1; then
                mv "$TMP_FILE" "$agents_file"
                MODIFIED=true
            else
                rm -f "$TMP_FILE"
            fi
        else
            rm -f "$TMP_FILE"
        fi

        if [ "$MODIFIED" = true ]; then
            FILES_MODIFIED_JSON=$(echo "$FILES_MODIFIED_JSON" | jq --arg f "$agents_file" 'if (. | index($f)) then . else . + [$f] end')
        fi
    done
done
```

**Step 4: Run test to verify it passes**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-deletions.sh`
Expected: `PASS: deletion fixing`

**Step 5: Commit**

```bash
git add scripts/drift-fix.sh tests/test-drift-fix-deletions.sh
git commit -m "feat: drift-fix.sh removes deleted file references from AGENTS.md table rows and bullet items"
```

---

## Task 5: Add Cross-AGENTS.md Link Fixing

Fix broken relative links between AGENTS.md files (e.g., `../api/AGENTS.md` when `api/` was renamed).

**Files:**
- Modify: `scripts/drift-fix.sh`
- Create: `tests/test-drift-fix-links.sh`

**Step 1: Write the failing test**

```bash
# tests/test-drift-fix-links.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

setup_test_repo
cd "$TEST_REPO"

# Add a directory rename to create broken AGENTS.md links
git mv src/api src/http
git commit -q -m "Rename api dir to http"

# Now src/core/AGENTS.md has a broken link: ../api/AGENTS.md should be ../http/AGENTS.md
# And root AGENTS.md has: src/api/AGENTS.md should be src/http/AGENTS.md

bash "$SCRIPT_DIR/../scripts/drift-fix.sh" > /dev/null 2>&1

# Check that links are fixed
grep -q "../http/AGENTS.md" src/core/AGENTS.md || { echo "FAIL: core AGENTS.md link not updated to ../http/"; cat src/core/AGENTS.md; exit 1; }
! grep -q "../api/AGENTS.md" src/core/AGENTS.md || { echo "FAIL: core AGENTS.md still has broken ../api/ link"; exit 1; }

grep -q "src/http/AGENTS.md" AGENTS.md || { echo "FAIL: root AGENTS.md link not updated to src/http/"; cat AGENTS.md; exit 1; }
! grep -q "src/api/AGENTS.md" AGENTS.md || { echo "FAIL: root AGENTS.md still has broken src/api/ link"; exit 1; }

cd - > /dev/null
cleanup_test_repo
echo "PASS: cross-AGENTS.md link fixing"
```

**Step 2: Run test to verify it fails**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-links.sh`
Expected: FAIL

**Step 3: Add link-fixing logic**

Insert after the deletion fixes section, before the final `jq -n` output:

```bash
# --- Cross-AGENTS.md link fixes ---
# Fix broken relative links between AGENTS.md files
# Only handles AGENTS.md link patterns, not arbitrary links

for agents_file in "${AGENTS_FILES[@]}"; do
    TMP_FILE=$(mktemp "${agents_file}.XXXXXX")
    MODIFIED=false

    while IFS= read -r line; do
        FIXED_LINE="$line"

        # Find AGENTS.md link references in this line
        # Patterns: (path/AGENTS.md), [text](path/AGENTS.md)
        # Extract paths that contain "AGENTS.md"
        while [[ "$FIXED_LINE" =~ ([a-zA-Z0-9_./-]+/AGENTS\.md) ]]; do
            LINK_PATH="${BASH_REMATCH[1]}"

            # Resolve the link relative to this AGENTS.md file's directory
            AGENTS_DIR=$(dirname "$agents_file")
            RESOLVED="$AGENTS_DIR/$LINK_PATH"

            # Normalize path
            RESOLVED=$(cd "$REPO_ROOT" && realpath -m --relative-to=. "$RESOLVED" 2>/dev/null || echo "$RESOLVED")

            # Check if the resolved path exists
            if [ ! -f "$RESOLVED" ]; then
                # Try to find the AGENTS.md by checking rename history
                # The directory part of the link may have been renamed
                LINK_DIR=$(dirname "$LINK_PATH")
                LINK_BASENAME=$(basename "$LINK_PATH")

                # Check renames for directory-level renames
                for rename_entry in $(echo "$RENAMES_JSON" | jq -c '.[]'); do
                    OLD_RENAME=$(echo "$rename_entry" | jq -r '.old')
                    NEW_RENAME=$(echo "$rename_entry" | jq -r '.new')
                    OLD_DIR=$(dirname "$OLD_RENAME")
                    NEW_DIR=$(dirname "$NEW_RENAME")

                    # If the old directory matches our broken link's target dir
                    if [[ "$RESOLVED" == *"$OLD_DIR"* ]]; then
                        NEW_LINK="${LINK_PATH/$OLD_DIR/$NEW_DIR}"
                        NEW_RESOLVED="$AGENTS_DIR/$NEW_LINK"
                        NEW_RESOLVED=$(cd "$REPO_ROOT" && realpath -m --relative-to=. "$NEW_RESOLVED" 2>/dev/null || echo "$NEW_RESOLVED")
                        if [ -f "$NEW_RESOLVED" ]; then
                            FIXED_LINE="${FIXED_LINE//$LINK_PATH/$NEW_LINK}"
                            LINKS_FIXED_JSON=$(echo "$LINKS_FIXED_JSON" | jq --arg old "$LINK_PATH" --arg new "$NEW_LINK" --arg file "$agents_file" '. + [{"file": $file, "old": $old, "new": $new}]')
                            MODIFIED=true
                            break
                        fi
                    fi
                done
            fi

            # Prevent infinite loop — remove the match we just processed
            break
        done

        echo "$FIXED_LINE"
    done < "$agents_file" > "$TMP_FILE"

    if [ "$MODIFIED" = true ]; then
        mv "$TMP_FILE" "$agents_file"
        FILES_MODIFIED_JSON=$(echo "$FILES_MODIFIED_JSON" | jq --arg f "$agents_file" 'if (. | index($f)) then . else . + [$f] end')
    else
        rm -f "$TMP_FILE"
    fi
done
```

**Step 4: Run test to verify it passes**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-links.sh`
Expected: `PASS: cross-AGENTS.md link fixing`

**Step 5: Commit**

```bash
git add scripts/drift-fix.sh tests/test-drift-fix-links.sh
git commit -m "feat: drift-fix.sh fixes broken cross-AGENTS.md relative links"
```

---

## Task 6: Add Idempotency and Edge Case Handling

Ensure the script is idempotent (running twice = no additional changes), handles unsupported table formats gracefully, and works with `flock`.

**Files:**
- Modify: `scripts/drift-fix.sh`
- Create: `tests/test-drift-fix-idempotent.sh`

**Step 1: Write the failing test**

```bash
# tests/test-drift-fix-idempotent.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

setup_test_repo
cd "$TEST_REPO"

# Run once
bash "$SCRIPT_DIR/../scripts/drift-fix.sh" > /tmp/drift-fix-run1.json 2>&1

# Snapshot the state
for f in AGENTS.md src/api/AGENTS.md src/core/AGENTS.md; do
    cp "$f" "$f.snapshot"
done

# Run again
bash "$SCRIPT_DIR/../scripts/drift-fix.sh" > /tmp/drift-fix-run2.json 2>&1

# Verify no additional changes
for f in AGENTS.md src/api/AGENTS.md src/core/AGENTS.md; do
    if ! diff -q "$f" "$f.snapshot" > /dev/null 2>&1; then
        echo "FAIL: $f changed on second run"
        diff "$f" "$f.snapshot"
        exit 1
    fi
done

# Verify second run reports no modifications
MODS=$(cat /tmp/drift-fix-run2.json | jq '.files_modified | length')
if [ "$MODS" -ne 0 ]; then
    echo "FAIL: second run reported $MODS modifications, expected 0"
    cat /tmp/drift-fix-run2.json | jq .
    exit 1
fi

cd - > /dev/null
cleanup_test_repo
echo "PASS: idempotency"
```

**Step 2: Run test to verify it fails**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-idempotent.sh`
Expected: FAIL (second run likely still reports changes because the reference commit hasn't moved)

**Step 3: Fix idempotency**

The key insight: after fixing, the AGENTS.md files are modified but not committed. The script uses "oldest AGENTS.md commit" as the baseline. On second run, the AGENTS.md commit hasn't changed (files are modified but not committed), so git still reports the same renames/deletions — but the references in AGENTS.md have already been updated.

The rename fix is naturally idempotent: if `handler.ts` has already been replaced with `controller.ts`, `sed` won't find `handler.ts` to replace. Similarly for deletions — if the line is already removed, `grep -v` won't remove anything new.

The issue is the `files_modified` tracking — we need to only report files that actually changed. Update the rename and deletion sections to compare before/after:

In each section where we do `mv "$TMP_FILE" "$agents_file"`, add a diff check first:

```bash
# Before mv, check if file actually changed
if ! diff -q "$agents_file" "$TMP_FILE" > /dev/null 2>&1; then
    mv "$TMP_FILE" "$agents_file"
    MODIFIED=true
else
    rm -f "$TMP_FILE"
fi
```

Apply this pattern to all three fix sections (renames, deletions, links).

**Step 4: Run test to verify it passes**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-idempotent.sh`
Expected: `PASS: idempotency`

**Step 5: Commit**

```bash
git add scripts/drift-fix.sh tests/test-drift-fix-idempotent.sh
git commit -m "feat: drift-fix.sh is idempotent — second run produces no changes"
```

---

## Task 7: Add Full Integration Test

A single test that runs the complete flow and verifies the JSON summary output.

**Files:**
- Create: `tests/test-drift-fix-integration.sh`

**Step 1: Write the integration test**

```bash
# tests/test-drift-fix-integration.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"

setup_test_repo
cd "$TEST_REPO"

# Run drift-fix.sh and capture JSON output
OUTPUT=$(bash "$SCRIPT_DIR/../scripts/drift-fix.sh" 2>/dev/null)

# Verify JSON structure
echo "$OUTPUT" | jq -e '
    has("renames") and
    has("deletions") and
    has("new_files") and
    has("links_fixed") and
    has("files_modified")
' > /dev/null || { echo "FAIL: invalid JSON structure"; echo "$OUTPUT"; exit 1; }

# Verify counts
RENAME_COUNT=$(echo "$OUTPUT" | jq '.renames | length')
DELETE_COUNT=$(echo "$OUTPUT" | jq '.deletions | length')
NEW_COUNT=$(echo "$OUTPUT" | jq '.new_files | length')
MOD_COUNT=$(echo "$OUTPUT" | jq '.files_modified | length')

[ "$RENAME_COUNT" -eq 2 ] || { echo "FAIL: expected 2 renames, got $RENAME_COUNT"; exit 1; }
[ "$DELETE_COUNT" -eq 1 ] || { echo "FAIL: expected 1 deletion, got $DELETE_COUNT"; exit 1; }
[ "$NEW_COUNT" -eq 1 ] || { echo "FAIL: expected 1 new file, got $NEW_COUNT"; exit 1; }
[ "$MOD_COUNT" -gt 0 ] || { echo "FAIL: expected >0 modified files, got $MOD_COUNT"; exit 1; }

# Verify AGENTS.md content is correct
# Root: controller.ts present, handler.ts gone
grep -q "controller.ts" AGENTS.md || { echo "FAIL: root missing controller.ts"; exit 1; }
! grep -q "handler.ts" AGENTS.md || { echo "FAIL: root still has handler.ts"; exit 1; }

# API: controller.ts and auth.ts present, originals gone
grep -q "controller.ts" src/api/AGENTS.md || { echo "FAIL: api missing controller.ts"; exit 1; }
grep -q "auth.ts" src/api/AGENTS.md || { echo "FAIL: api missing auth.ts"; exit 1; }

# Core: worker.ts removed, engine.ts and scheduler.ts preserved
! grep -q "worker.ts" src/core/AGENTS.md || { echo "FAIL: core still has worker.ts"; exit 1; }
grep -q "engine.ts" src/core/AGENTS.md || { echo "FAIL: core lost engine.ts"; exit 1; }
grep -q "scheduler.ts" src/core/AGENTS.md || { echo "FAIL: core lost scheduler.ts"; exit 1; }

# New files: cache.ts detected
echo "$OUTPUT" | jq -e '.new_files[] | select(. == "src/core/cache.ts")' > /dev/null || { echo "FAIL: cache.ts not in new_files"; exit 1; }

# Performance: should complete in <2 seconds (generous for test repo)
cd - > /dev/null
cleanup_test_repo
echo "PASS: integration test"
```

**Step 2: Run integration test**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/test-drift-fix-integration.sh`
Expected: `PASS: integration test`

**Step 3: Create test runner for all tests**

```bash
# tests/run-all.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

for test_file in "$SCRIPT_DIR"/test-drift-fix-*.sh; do
    echo "--- Running $(basename "$test_file") ---"
    if bash "$test_file"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

**Step 4: Run all tests**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/run-all.sh`
Expected: All tests pass

**Step 5: Commit**

```bash
git add tests/test-drift-fix-integration.sh tests/run-all.sh
git commit -m "test: add integration test and test runner for drift-fix.sh"
```

---

## Task 8: Add Fix Mode to SKILL.md

Update the Interdoc skill definition to support `/interdoc fix` and the "fix stale references" natural language trigger.

**Files:**
- Modify: `skills/interdoc/SKILL.md`

**Step 1: Read the current SKILL.md frontmatter and mode detection section**

Read: `skills/interdoc/SKILL.md` (lines 1-10 for frontmatter, lines 96-102 for mode detection)

**Step 2: Update SKILL.md frontmatter to include fix trigger**

In `skills/interdoc/SKILL.md`, change the `description` field in the frontmatter:

```yaml
---
name: interdoc
description: Generate, update, and review AGENTS.md with GPT 5.2 Pro critique. Use when asked to "generate AGENTS.md", "update AGENTS.md", "document this repo", "document this codebase", "review docs", "critique docs", "fix stale references", "fix docs", "interdoc fix", or "auracoil".
---
```

**Step 3: Add Fix Mode to Mode Detection section**

After the existing mode detection block (around line 102), insert a new mode:

```markdown
## Mode Detection

The skill automatically detects which mode to use:

- **Fix phrases present** → Fix mode (structural fixes only, no LLM)
- **No AGENTS.md exists** → Generation mode (full recursive pass)
- **AGENTS.md exists** → Update mode (targeted pass on changed directories)

**Fix mode triggers:** "fix stale references", "fix docs", "interdoc fix", "fix broken links", "structural fix"
```

**Step 4: Add Fix Mode Workflow section**

Insert a new workflow section before the Generation Mode Workflow (after the `<workflows>` tag):

```markdown
# Fix Mode Workflow (Structural Auto-Fix)

Fast, deterministic fixes for stale AGENTS.md file references. No LLM tokens — uses git history and sed.

## When to Use

- Files were renamed, deleted, or added since the last AGENTS.md update
- Cross-AGENTS.md links are broken due to directory renames
- You want to fix structural drift without a full regeneration

## Step 1: Run drift-fix.sh

```bash
bash scripts/drift-fix.sh --dry-run
```

This outputs a JSON summary: `{"renames": [...], "deletions": [...], "new_files": [...], "links_fixed": [], "files_modified": []}`.

If the summary shows zero renames, zero deletions, and zero new files, respond: **"All AGENTS.md references are current."** and stop.

## Step 2: Show Diff Preview

Show the user what will change using unified diffs:

```bash
# For each AGENTS.md that will be modified, show the diff
bash scripts/drift-fix.sh --dry-run | jq -r '.renames[], .deletions[]'
```

Present the changes:
```
Structural drift detected:
- 2 renames (handler.ts → controller.ts, middleware.ts → auth.ts)
- 1 deletion (worker.ts removed from core AGENTS.md)
- 1 new file detected (cache.ts — not auto-added, use full /interdoc to add)

📁 AGENTS.md
```diff
-| `src/api/handler.ts` | API request handler |
+| `src/api/controller.ts` | API request handler |
```

📁 src/core/AGENTS.md
```diff
-- `worker.ts` — Worker pool implementation
```

Apply these fixes? [A]pply / [S]kip
```

## Step 3: Apply Fixes

```bash
bash scripts/drift-fix.sh
```

Report summary: **"2 renames updated, 1 deleted reference removed, 1 new file detected."**

## Step 4: Suggest Full Update if Needed

If new files were detected:
```
Note: 1 new file detected (src/core/cache.ts) but not auto-added.
Run `/interdoc` for a full update to add new file descriptions (requires LLM).
```

---
```

**Step 5: Add structural-only detection to full invocation**

At the start of the Update Mode Workflow Step 1, add this check:

```markdown
**Structural-only shortcut:** Before running the full update, check if changes are purely structural:

```bash
OUTPUT=$(bash scripts/drift-fix.sh --dry-run 2>/dev/null)
RENAMES=$(echo "$OUTPUT" | jq '.renames | length')
DELETIONS=$(echo "$OUTPUT" | jq '.deletions | length')
```

If renames + deletions > 0 and no semantic changes are detected (no new sections needed, no architecture changes), suggest:

> "Detected only file renames/deletions. Run `/interdoc fix` for a faster update (no LLM tokens)."
```

**Step 6: Commit**

```bash
git add skills/interdoc/SKILL.md
git commit -m "feat: add Fix mode to SKILL.md — /interdoc fix for structural auto-fix"
```

---

## Task 9: Update Plugin Metadata and Documentation

Update AGENTS.md, CLAUDE.md, and README.md to reflect the new Fix mode.

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `README.md` (if it lists modes)

**Step 1: Read current README.md**

Read: `README.md` to understand its current structure.

**Step 2: Update AGENTS.md**

Add Fix mode to the command quick reference table and the Key Features list. Add `scripts/drift-fix.sh` and `tests/` to the repository structure diagram.

In the Repository Structure section, add:
```
├── scripts/
│   ├── drift-fix.sh       # Structural auto-fix (renames, deletions, link fixes)
│   ├── bump-version.sh    # Version management
│   └── ...
├── tests/
│   ├── fixtures/
│   │   └── setup-test-repo.sh  # Test repo scaffolding
│   ├── test-drift-fix-*.sh     # drift-fix.sh test suite
│   └── run-all.sh              # Test runner
```

In the Key Features section, add:
```
- **Structural auto-fix**: Deterministic rename/deletion/link fixes without LLM tokens
```

In the command quick reference table, add:
```
| "fix stale references" / "interdoc fix" | Fix | Structural only (no LLM) |
```

**Step 3: Update README.md with Fix mode**

Add a section or update the modes table to include Fix mode.

**Step 4: Commit**

```bash
git add AGENTS.md CLAUDE.md README.md
git commit -m "docs: update AGENTS.md, CLAUDE.md, README.md with Fix mode and drift-fix.sh"
```

---

## Task 10: Run Full Test Suite and Final Verification

Run all tests, verify idempotency, check that the script works on the actual Interverse monorepo.

**Files:**
- No new files

**Step 1: Run all drift-fix tests**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash tests/run-all.sh`
Expected: All tests pass

**Step 2: Verify script syntax**

Run: `bash -n scripts/drift-fix.sh && echo "SYNTAX OK"`
Expected: `SYNTAX OK`

**Step 3: Test on real repo (dry-run)**

Run: `cd /root/projects/Interverse/plugins/interdoc && bash scripts/drift-fix.sh --dry-run`
Expected: JSON output with current structural drift (may be empty if no renames/deletions since last AGENTS.md update)

**Step 4: Verify plugin.json is still valid**

Run: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('VALID')"`
Expected: `VALID`

**Step 5: Commit any final fixes**

If any issues found, fix and commit.

---

## Summary

| Task | What | Key Files |
|------|------|-----------|
| 1 | Test fixtures (temp git repo) | `tests/fixtures/setup-test-repo.sh` |
| 2 | Git diff parsing skeleton | `scripts/drift-fix.sh`, `tests/test-drift-fix-parsing.sh` |
| 3 | Rename fixing | `scripts/drift-fix.sh`, `tests/test-drift-fix-renames.sh` |
| 4 | Deletion fixing | `scripts/drift-fix.sh`, `tests/test-drift-fix-deletions.sh` |
| 5 | Cross-AGENTS.md link fixing | `scripts/drift-fix.sh`, `tests/test-drift-fix-links.sh` |
| 6 | Idempotency + edge cases | `scripts/drift-fix.sh`, `tests/test-drift-fix-idempotent.sh` |
| 7 | Integration test + runner | `tests/test-drift-fix-integration.sh`, `tests/run-all.sh` |
| 8 | SKILL.md Fix mode | `skills/interdoc/SKILL.md` |
| 9 | Docs update | `AGENTS.md`, `README.md` |
| 10 | Final verification | (no new files) |
