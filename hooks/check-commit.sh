#!/bin/bash
# Check if a git commit just happened and suggest Interdoc review

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Check if CLAUDE.md exists (if not, skip reminder)
if [ ! -f "CLAUDE.md" ]; then
    exit 0
fi

# Get the timestamp of the last commit
LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo 0)
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_COMMIT_TIME))

# If a commit happened in the last 10 seconds
if [ "$TIME_DIFF" -lt 10 ]; then
    # Track state in temp file to avoid duplicate reminders
    STATE_FILE="/tmp/interdoc-last-check-$$"

    # Check if we already reminded for this commit
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

    # Count commits since last CLAUDE.md update
    if [ "$CLAUDE_UPDATE_TIME" -gt 0 ]; then
        COMMITS_SINCE=$(git log --since="@$CLAUDE_UPDATE_TIME" --oneline | wc -l | tr -d ' ')

        # Show reminder at thresholds (3, 5, 10, 15, 20)
        if [ "$COMMITS_SINCE" -eq 3 ] || [ "$COMMITS_SINCE" -eq 5 ] || [ "$COMMITS_SINCE" -eq 10 ] || [ "$COMMITS_SINCE" -eq 15 ] || [ "$COMMITS_SINCE" -eq 20 ]; then
            echo ""
            echo "💡 Interdoc reminder: $COMMITS_SINCE commits since last CLAUDE.md update"
            echo "   Consider running: 'update CLAUDE.md' to review documentation needs"
            echo ""
        fi
    fi
fi
