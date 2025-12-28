#!/bin/bash
# Suggest /interdoc when documentation may be needed

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# If no CLAUDE.md exists, suggest generating one
if [ ! -f "CLAUDE.md" ]; then
    echo "No CLAUDE.md found. Use /interdoc to generate documentation for this project."
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

# If there are 3+ commits, suggest updating
if [ "$COMMITS_SINCE" -ge 3 ]; then
    echo "There are $COMMITS_SINCE commits since CLAUDE.md was last updated. Use /interdoc to update documentation."
fi
