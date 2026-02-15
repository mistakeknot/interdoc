#!/bin/bash
# interdoc advisory audit: coverage + lightweight lint. Non-blocking.

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository."
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
cd "$REPO_ROOT"

# Check for cached directory candidates
CACHE_FILE=".git/interdoc/candidates.json"
CURRENT_COMMIT=$(git rev-parse HEAD)
USE_CACHE=false

if [ -f "$CACHE_FILE" ]; then
  CACHED_COMMIT=$(jq -r '.repo_commit // empty' "$CACHE_FILE" 2>/dev/null || echo "")
  if [ "$CACHED_COMMIT" = "$CURRENT_COMMIT" ]; then
    USE_CACHE=true
  fi
fi

if [ "$USE_CACHE" = true ]; then
  # Use cached candidates
  warrant_dirs=$(jq -r '.candidates[].path' "$CACHE_FILE" 2>/dev/null | sort -u)
else
  # Build list of directories that warrant AGENTS.md (fresh scan)
  # Use xargs -r to handle empty input gracefully
  manifest_dirs=$(find . \( \
    -name "package.json" -o -name "Cargo.toml" -o -name "go.mod" -o \
    -name "pyproject.toml" -o -name "requirements.txt" \
  \) -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 2>/dev/null \
    | xargs -0 -r dirname 2>/dev/null | sort -u || echo "")

  src_dirs=$(find . -type f \( \
    -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o \
    -name "*.rs" -o -name "*.java" \
  \) -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 2>/dev/null \
    | xargs -0 -r dirname 2>/dev/null | sort \
    | awk '{count[$0]++} END {for (d in count) if (count[d] >= 5) print d}' | sort -u || echo "")

  warrant_dirs=$(printf "%s\n%s\n" "$manifest_dirs" "$src_dirs" | sort -u | sed '/^$/d')

  # Update cache for future runs
  if [ -n "$warrant_dirs" ]; then
    mkdir -p .git/interdoc
    CANDIDATES_JSON=$(echo "$warrant_dirs" | jq -R -s 'split("\n") | map(select(length > 0)) | map({path: ., reason: "scan", source_count: 0, has_agents_md: false})')
    cat > "$CACHE_FILE" << EOF
{
  "schema": "interdoc.candidates.v1",
  "repo_commit": "$CURRENT_COMMIT",
  "timestamp": $(date +%s),
  "candidates": $CANDIDATES_JSON
}
EOF
  fi
fi

if [ -z "$warrant_dirs" ]; then
  echo "[interdoc-audit] No directories meet coverage criteria."
  exit 0
fi

missing=()
covered=0

total=$(echo "$warrant_dirs" | wc -l | tr -d ' ')

while IFS= read -r d; do
  if [ -f "$d/AGENTS.md" ]; then
    covered=$((covered + 1))
  else
    missing+=("$d")
  fi
  done <<< "$warrant_dirs"

percent=$((covered * 100 / total))

echo "[interdoc-audit] Coverage: ${percent}% (${covered}/${total})"
if [ ${#missing[@]} -gt 0 ]; then
  echo "[interdoc-audit] Missing AGENTS.md:" 
  for d in "${missing[@]}"; do
    echo "- $d"
  done
fi

# Lightweight lint for root AGENTS.md
if [ -f "AGENTS.md" ]; then
  required=("Purpose" "Key Files" "Architecture" "Conventions" "Gotchas")
  for section in "${required[@]}"; do
    if ! grep -q "^## ${section}" AGENTS.md; then
      echo "[interdoc-audit] Lint: Missing section '## ${section}' in AGENTS.md"
    fi
  done

  # Empty Gotchas section check
  if grep -q "^## Gotchas" AGENTS.md; then
    gotchas_content=$(awk 'found && /^## /{exit} found{print} /^## Gotchas/{found=1}' AGENTS.md | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    if [ "$gotchas_content" -eq 0 ]; then
      echo "[interdoc-audit] Lint: Gotchas section is empty"
    fi
  fi

  # Paragraph length check (>6 lines)
  if awk 'BEGIN{c=0} /^#/{c=0; next} /^$/{c=0; next} {c++; if(c>6){print 1; exit}}' AGENTS.md | grep -q 1; then
    echo "[interdoc-audit] Lint: Found paragraph longer than ~6 lines"
  fi
fi
