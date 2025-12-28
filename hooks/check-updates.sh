#!/bin/bash
# Suggest Interdoc when documentation may be needed
# Triggers: No AGENTS.md, 7+ days since update, or 10+ commits since update

# Only run if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# If no AGENTS.md exists, suggest generating one
if [ ! -f "AGENTS.md" ]; then
    echo "No AGENTS.md found. Consider generating documentation for this project using the Interdoc skill."
    exit 0
fi

# Get the last AGENTS.md update commit and time
AGENTS_UPDATE_COMMIT=$(git log -1 --format=%H AGENTS.md 2>/dev/null)
AGENTS_UPDATE_TIME=$(git log -1 --format=%ct AGENTS.md 2>/dev/null || echo 0)

# If AGENTS.md has never been committed, skip
if [ -z "$AGENTS_UPDATE_COMMIT" ] || [ "$AGENTS_UPDATE_TIME" -eq 0 ]; then
    exit 0
fi

# Calculate days since update
CURRENT_TIME=$(date +%s)
DAYS_SINCE=$(( (CURRENT_TIME - AGENTS_UPDATE_TIME) / 86400 ))

# Count commits since last AGENTS.md update
COMMITS_SINCE=$(git rev-list --count "$AGENTS_UPDATE_COMMIT"..HEAD 2>/dev/null || echo 0)

# Trigger if 7+ days since update
if [ "$DAYS_SINCE" -ge 7 ]; then
    echo "AGENTS.md was last updated $DAYS_SINCE days ago. Consider updating documentation using the Interdoc skill."
    exit 0
fi

# Trigger if 10+ commits since update
if [ "$COMMITS_SINCE" -ge 10 ]; then
    echo "There are $COMMITS_SINCE commits since AGENTS.md was last updated. Consider updating documentation using the Interdoc skill."
fi
