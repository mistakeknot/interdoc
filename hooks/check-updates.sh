#!/bin/bash
# Check for pending CLAUDE.md updates and prompt Claude to review them automatically

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Check if CLAUDE.md exists
if [ ! -f "CLAUDE.md" ]; then
    exit 0
fi

# Get the last CLAUDE.md update time
CLAUDE_UPDATE_TIME=$(git log -1 --format=%ct CLAUDE.md 2>/dev/null || echo 0)

# If CLAUDE.md has never been committed, skip
if [ "$CLAUDE_UPDATE_TIME" -eq 0 ]; then
    exit 0
fi

# Count commits since last CLAUDE.md update
COMMITS_SINCE=$(git log --since="@$CLAUDE_UPDATE_TIME" --oneline 2>/dev/null | wc -l | tr -d ' ')

# If there are 3+ commits, prompt Claude to review
if [ "$COMMITS_SINCE" -ge 3 ]; then
    # Check for quick scan of changes (new files, config changes)
    SIGNIFICANT_CHANGES=$(git diff --name-only "@$CLAUDE_UPDATE_TIME" HEAD 2>/dev/null | grep -E '(^[^/]+/$|package\.json|tsconfig\.json|Cargo\.toml|\.claude-plugin|requirements\.txt|go\.mod)' | wc -l | tr -d ' ')

    if [ "$COMMITS_SINCE" -ge 10 ] || [ "$SIGNIFICANT_CHANGES" -gt 0 ]; then
        # Output prompt that will be injected into Claude's context
        cat <<EOF
There are $COMMITS_SINCE commits since CLAUDE.md was last updated. Please use the Interdoc skill to review and suggest documentation updates. Analyze the commits, categorize changes, and present suggestions for the user to approve.
EOF
    fi
fi
