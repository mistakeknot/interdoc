#!/bin/bash
# Suggest Interdoc after significant commits accumulate mid-session
# Triggers at 15+ commits since last AGENTS.md update

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Check if AGENTS.md exists
if [ ! -f "AGENTS.md" ]; then
    exit 0
fi

# Get the timestamp of the last commit
LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo 0)
if [ "$LAST_COMMIT_TIME" -eq 0 ]; then
    exit 0
fi

CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_COMMIT_TIME))

# Only proceed if a commit happened in the last 5 seconds
if [ "$TIME_DIFF" -gt 5 ]; then
    exit 0
fi

# Get the last AGENTS.md update commit
AGENTS_UPDATE_COMMIT=$(git log -1 --format=%H AGENTS.md 2>/dev/null)
if [ -z "$AGENTS_UPDATE_COMMIT" ]; then
    exit 0
fi

# Count commits since last AGENTS.md update
COMMITS_SINCE=$(git rev-list --count "$AGENTS_UPDATE_COMMIT"..HEAD 2>/dev/null || echo 0)

# Trigger at higher threshold (15 commits) for mid-session
if [ "$COMMITS_SINCE" -ge 15 ]; then
    # Prevent re-triggering until AGENTS.md is updated
    TRIGGER_MARKER="/tmp/interdoc-triggered-$(echo "$AGENTS_UPDATE_COMMIT" | cut -c1-8)"
    if [ -f "$TRIGGER_MARKER" ]; then
        exit 0
    fi
    touch "$TRIGGER_MARKER"

    echo "There are now $COMMITS_SINCE commits since AGENTS.md was last updated. Consider updating documentation using the Interdoc skill."
fi
