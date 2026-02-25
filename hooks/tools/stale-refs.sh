#!/usr/bin/env bash
# stale-refs.sh — Deterministic stale-reference checker for AGENTS.md
#
# Extracts file paths and commands from AGENTS.md and checks if they
# still exist on disk. Reports stale references without an LLM call.
#
# Usage: stale-refs.sh <repo-root> [agents-md-path]
#
# Output: JSON array of findings, one per stale reference.
# Exit codes:
#   0  No stale references found
#   1  Stale references found
#   2  Fatal error (missing file, bad args)

set -euo pipefail

REPO_ROOT="${1:-}"
AGENTS_MD="${2:-}"

if [[ -z "$REPO_ROOT" ]]; then
  echo '{"error":"missing-args","message":"Usage: stale-refs.sh <repo-root> [agents-md-path]"}' >&2
  exit 2
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

# Auto-detect AGENTS.md if not specified
if [[ -z "$AGENTS_MD" ]]; then
  if [[ -f "$REPO_ROOT/AGENTS.md" ]]; then
    AGENTS_MD="$REPO_ROOT/AGENTS.md"
  else
    echo '{"error":"not-found","message":"No AGENTS.md found in repo root"}' >&2
    exit 2
  fi
fi

if [[ ! -f "$AGENTS_MD" ]]; then
  echo '{"error":"not-found","message":"AGENTS.md not found at '"$AGENTS_MD"'"}' >&2
  exit 2
fi

findings=()

# ---------------------------------------------------------------------------
# Check 1: File path references
# ---------------------------------------------------------------------------
# Extract paths that look like file references (relative paths with extensions
# or directory paths). Match patterns like:
#   `src/foo/bar.go`
#   src/foo/bar.go
#   `./scripts/deploy.sh`

while IFS= read -r path; do
  # Skip URLs, anchors, and obviously non-file references
  [[ "$path" =~ ^https?:// ]] && continue
  [[ "$path" =~ ^#  ]] && continue
  [[ "$path" =~ ^\$ ]] && continue  # shell variables like $HOME
  [[ "$path" =~ ^~ ]] && continue   # home directory refs
  [[ -z "$path" ]] && continue

  # Resolve relative to repo root
  full_path="$REPO_ROOT/$path"

  if [[ ! -e "$full_path" ]]; then
    findings+=("{\"type\":\"stale_path\",\"path\":\"$path\",\"message\":\"Referenced file/directory does not exist\"}")
  fi
done < <(
  # Extract backtick-enclosed paths with file extensions or directory separators
  grep -oE '`[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+`' "$AGENTS_MD" 2>/dev/null |
    tr -d '`' |
    grep '/' |
    grep -v '^http' |
    sort -u

  # Extract paths from markdown links [text](path)
  grep -oE '\]\([a-zA-Z0-9_./-]+\)' "$AGENTS_MD" 2>/dev/null |
    sed 's/^](//' | sed 's/)$//' |
    grep '/' |
    grep -v '^http' |
    sort -u
)

# ---------------------------------------------------------------------------
# Check 2: Command references in code blocks
# ---------------------------------------------------------------------------
# Extract first word of bash code block lines (commands) and check if binary exists.

while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  # Skip common shell builtins and control flow
  case "$cmd" in
    if|then|else|fi|for|do|done|while|case|esac|echo|printf|export|set|cd|pwd|ls|cat|mkdir|rm|cp|mv|true|false|test|return|exit|source) continue ;;
  esac
  # Skip variable assignments
  [[ "$cmd" =~ = ]] && continue
  # Skip if it's a relative path to a file that exists
  [[ -f "$REPO_ROOT/$cmd" ]] && continue

  # Check if command exists on PATH or in repo
  if ! command -v "$cmd" >/dev/null 2>&1 && [[ ! -x "$REPO_ROOT/$cmd" ]]; then
    findings+=("{\"type\":\"missing_command\",\"command\":\"$cmd\",\"message\":\"Referenced command not found on PATH\"}")
  fi
done < <(
  # Extract commands from bash/shell code blocks
  awk '/^```(bash|sh|shell)$/,/^```$/' "$AGENTS_MD" 2>/dev/null |
    grep -v '^```' |
    sed 's/#.*//' |         # strip comments
    sed 's/^\s*//' |        # strip leading whitespace
    grep -v '^\s*$' |       # skip empty lines
    cut -d' ' -f1 |         # first word = command
    sort -u
)

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ ${#findings[@]} -eq 0 ]]; then
  echo '{"status":"clean","findings":[]}'
  exit 0
else
  # Build JSON array
  json="["
  for i in "${!findings[@]}"; do
    [[ $i -gt 0 ]] && json+=","
    json+="${findings[$i]}"
  done
  json+="]"
  echo "{\"status\":\"stale\",\"count\":${#findings[@]},\"findings\":$json}"
  exit 1
fi
