#!/bin/bash
# Detect when Claude makes a git commit and trigger Interdoc at meaningful thresholds

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

# Track state to avoid duplicate triggers
STATE_FILE="/tmp/interdoc-commit-check-$$"
if [ -f "$STATE_FILE" ]; then
    LAST_CHECKED=$(cat "$STATE_FILE")
    if [ "$LAST_CHECKED" = "$LAST_COMMIT_TIME" ]; then
        exit 0
    fi
fi

# Save that we checked this commit
echo "$LAST_COMMIT_TIME" > "$STATE_FILE"

# Get the last CLAUDE.md update time
CLAUDE_UPDATE_TIME=$(git log -1 --format=%ct CLAUDE.md 2>/dev/null || echo 0)
if [ "$CLAUDE_UPDATE_TIME" -eq 0 ]; then
    exit 0
fi

# Count commits since last CLAUDE.md update
COMMITS_SINCE=$(git log --since="@$CLAUDE_UPDATE_TIME" --oneline 2>/dev/null | wc -l | tr -d ' ')

# Trigger Interdoc at higher threshold (10 commits) for mid-session updates
# This is higher than SessionStart threshold (3) to avoid interrupting frequently
if [ "$COMMITS_SINCE" -ge 10 ]; then
    # Check for significant changes
    SIGNIFICANT_CHANGES=$(git diff --name-only "@$CLAUDE_UPDATE_TIME" HEAD 2>/dev/null | grep -E '(package\.json|tsconfig\.json|Cargo\.toml|\.claude-plugin|requirements\.txt|go\.mod)' | wc -l | tr -d ' ')

    # Create a marker to prevent re-triggering until CLAUDE.md is updated
    TRIGGER_MARKER="/tmp/interdoc-triggered-$CLAUDE_UPDATE_TIME"
    if [ -f "$TRIGGER_MARKER" ]; then
        exit 0
    fi

    # Mark that we've triggered for this CLAUDE.md state
    touch "$TRIGGER_MARKER"

    # Output prompt to trigger Interdoc
    cat <<EOF
You just committed changes, and there are now $COMMITS_SINCE commits since CLAUDE.md was last updated. Please use the Interdoc skill to review and suggest documentation updates. Analyze the commits, categorize changes, and present suggestions for the user to approve.
EOF
fi
