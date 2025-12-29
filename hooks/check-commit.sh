#!/bin/bash
# Suggest Interdoc after significant commits accumulate mid-session
# Triggers at 15+ commits since last AGENTS.md update
#
# Improvements over v1:
# - Always operates from repo root (fixes subdirectory invocation bug)
# - Uses per-repo state in .git/interdoc/ instead of /tmp (no cross-repo collision)
# - Tracks HEAD changes instead of 5-second timing heuristic
# - Atomic locking to prevent race conditions
# - Handles shallow clones gracefully
# - Skips if AGENTS.md has uncommitted changes

set -euo pipefail

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Always operate from repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$REPO_ROOT"

# Check if AGENTS.md exists at repo root
if [ ! -f "AGENTS.md" ]; then
    exit 0
fi

# Skip if AGENTS.md has uncommitted changes
if [ -n "$(git status --porcelain -- AGENTS.md 2>/dev/null)" ]; then
    exit 0
fi

# Get current HEAD
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null) || exit 0

# Get per-repo state directory (works with worktrees too)
STATE_DIR=$(git rev-parse --git-path interdoc 2>/dev/null) || exit 0
mkdir -p "$STATE_DIR"

LAST_SEEN_FILE="$STATE_DIR/last-seen-head"
PROMPTED_FOR_FILE="$STATE_DIR/prompted-for-agents-commit"

# Check if HEAD has changed since last check
if [ -f "$LAST_SEEN_FILE" ]; then
    LAST_SEEN_HEAD=$(cat "$LAST_SEEN_FILE" 2>/dev/null) || LAST_SEEN_HEAD=""
    if [ "$CURRENT_HEAD" = "$LAST_SEEN_HEAD" ]; then
        # HEAD hasn't changed, nothing to do
        exit 0
    fi
fi

# Update last seen HEAD (atomic write)
echo "$CURRENT_HEAD" > "$LAST_SEEN_FILE.tmp" && mv "$LAST_SEEN_FILE.tmp" "$LAST_SEEN_FILE"

# Get the last AGENTS.md update commit
AGENTS_UPDATE_COMMIT=$(git log -1 --format=%H -- AGENTS.md 2>/dev/null) || exit 0
if [ -z "$AGENTS_UPDATE_COMMIT" ]; then
    exit 0
fi

# Check if we already prompted for this AGENTS.md commit
if [ -f "$PROMPTED_FOR_FILE" ]; then
    PROMPTED_COMMIT=$(cat "$PROMPTED_FOR_FILE" 2>/dev/null) || PROMPTED_COMMIT=""
    if [ "$PROMPTED_COMMIT" = "$AGENTS_UPDATE_COMMIT" ]; then
        # Already prompted since last AGENTS.md update
        exit 0
    fi
fi

# Count commits since last AGENTS.md update
# Handle shallow clones gracefully
COMMITS_SINCE=$(git rev-list --count "$AGENTS_UPDATE_COMMIT"..HEAD 2>/dev/null) || COMMITS_SINCE=""

# Skip if we couldn't count (shallow clone)
if [ -z "$COMMITS_SINCE" ]; then
    exit 0
fi

# Trigger at 15+ commits threshold for mid-session
if [ "$COMMITS_SINCE" -ge 15 ]; then
    # Use atomic directory creation as lock to prevent race conditions
    LOCK_DIR="$STATE_DIR/prompt.lock"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        # We got the lock, record that we prompted
        echo "$AGENTS_UPDATE_COMMIT" > "$PROMPTED_FOR_FILE.tmp" && mv "$PROMPTED_FOR_FILE.tmp" "$PROMPTED_FOR_FILE"
        rmdir "$LOCK_DIR"

        echo "There are now $COMMITS_SINCE commits since AGENTS.md was last updated. Consider updating documentation using the Interdoc skill."
    fi
    # If we didn't get the lock, another process is handling it
fi
