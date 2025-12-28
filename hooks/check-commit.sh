#!/bin/bash
# Suggest /interdoc after significant commits accumulate mid-session

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Check if CLAUDE.md exists
if [ ! -f "CLAUDE.md" ]; then
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

# Get the last CLAUDE.md update time
CLAUDE_UPDATE_TIME=$(git log -1 --format=%ct CLAUDE.md 2>/dev/null || echo 0)
if [ "$CLAUDE_UPDATE_TIME" -eq 0 ]; then
    exit 0
fi

# Count commits since last CLAUDE.md update
COMMITS_SINCE=$(git log --since="@$CLAUDE_UPDATE_TIME" --oneline 2>/dev/null | wc -l | tr -d ' ')

# Trigger at higher threshold (10 commits) for mid-session
if [ "$COMMITS_SINCE" -ge 10 ]; then
    # Prevent re-triggering until CLAUDE.md is updated
    TRIGGER_MARKER="/tmp/interdoc-triggered-$CLAUDE_UPDATE_TIME"
    if [ -f "$TRIGGER_MARKER" ]; then
        exit 0
    fi
    touch "$TRIGGER_MARKER"

    echo "There are now $COMMITS_SINCE commits since CLAUDE.md was last updated. Please update documentation using the Interdoc skill."
fi
