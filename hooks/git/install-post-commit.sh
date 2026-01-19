#!/bin/bash
# Install advisory post-commit hook for Interdoc (non-blocking).

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository."
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
cd "$REPO_ROOT"

HOOK_SRC="$REPO_ROOT/hooks/git/post-commit"
HOOK_DST="$REPO_ROOT/.git/hooks/post-commit"

if [ ! -f "$HOOK_SRC" ]; then
  echo "Missing hook source: $HOOK_SRC"
  exit 1
fi

if [ -f "$HOOK_DST" ] || [ -L "$HOOK_DST" ]; then
  BACKUP="$HOOK_DST.bak.$(date +%Y%m%d%H%M%S)"
  mv "$HOOK_DST" "$BACKUP"
  echo "Existing hook backed up to $BACKUP"
fi

ln -s "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"

echo "Installed Interdoc advisory post-commit hook."
