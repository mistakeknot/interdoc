#!/bin/bash
# Interdoc advisory audit: coverage + lightweight lint. Non-blocking.

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository."
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
cd "$REPO_ROOT"

# Build list of directories that warrant AGENTS.md
manifest_dirs=$(find . \( \
  -name "package.json" -o -name "Cargo.toml" -o -name "go.mod" -o \
  -name "pyproject.toml" -o -name "requirements.txt" \
\) -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 2>/dev/null \
  | xargs -0 -I{} dirname {} | sort -u)

src_dirs=$(find . -type f \( \
  -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o \
  -name "*.rs" -o -name "*.java" \
\) -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 2>/dev/null \
  | xargs -0 dirname | sort \
  | awk '{count[$0]++} END {for (d in count) if (count[d] >= 5) print d}' | sort -u)

warrant_dirs=$(printf "%s\n%s\n" "$manifest_dirs" "$src_dirs" | sort -u | sed '/^$/d')

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
