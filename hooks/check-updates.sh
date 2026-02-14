#!/bin/bash
# Suggest Interdoc when documentation may be needed
# Triggers: No AGENTS.md, 7+ days since update, or 10+ commits since update
#
# Improvements over v1:
# - Always operates from repo root (fixes subdirectory invocation bug)
# - Handles shallow clones gracefully
# - Skips if AGENTS.md has uncommitted changes
# - Uses git-path for reliable path resolution

set -euo pipefail

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Always operate from repo root to find AGENTS.md correctly
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$REPO_ROOT"

# If no AGENTS.md exists at repo root, suggest generating one
if [ ! -f "AGENTS.md" ]; then
    echo '{"action": "generate", "reason": "no_agents_md"}'
    exit 0
fi

# Skip if AGENTS.md has uncommitted changes (user is actively editing)
if [ -n "$(git status --porcelain -- AGENTS.md 2>/dev/null)" ]; then
    exit 0
fi

# Get the last AGENTS.md update commit and time
AGENTS_UPDATE_COMMIT=$(git log -1 --format=%H -- AGENTS.md 2>/dev/null) || true
AGENTS_UPDATE_TIME=$(git log -1 --format=%ct -- AGENTS.md 2>/dev/null) || true

# If AGENTS.md exists but has never been committed, suggest committing it
if [ -z "$AGENTS_UPDATE_COMMIT" ] || [ -z "$AGENTS_UPDATE_TIME" ]; then
    echo '{"action": "update", "reason": "uncommitted"}'
    exit 0
fi

# Calculate days since update
CURRENT_TIME=$(date +%s)
DAYS_SINCE=$(( (CURRENT_TIME - AGENTS_UPDATE_TIME) / 86400 ))

# Count commits since last AGENTS.md update
# Handle shallow clones: if rev-list fails, fall back to days-only check
COMMITS_SINCE=$(git rev-list --count "$AGENTS_UPDATE_COMMIT"..HEAD 2>/dev/null) || COMMITS_SINCE=""

# Trigger if 7+ days since update
if [ "$DAYS_SINCE" -ge 7 ]; then
    echo "{\"action\": \"update\", \"reason\": \"stale\", \"days_since\": $DAYS_SINCE}"
    exit 0
fi

# Trigger if 10+ commits since update (skip if shallow clone prevented count)
if [ -n "$COMMITS_SINCE" ] && [ "$COMMITS_SINCE" -ge 10 ]; then
    echo "{\"action\": \"update\", \"reason\": \"commits\", \"commits_since\": $COMMITS_SINCE}"
    exit 0
fi

# Handle shallow clone: if we couldn't count commits but it's been a few days, suggest update
if [ -z "$COMMITS_SINCE" ] && [ "$DAYS_SINCE" -ge 3 ]; then
    echo "{\"action\": \"update\", \"reason\": \"stale_shallow\", \"days_since\": $DAYS_SINCE}"
fi
