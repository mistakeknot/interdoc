#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SKIP_PREFLIGHT=false
TIMEOUT=300
REPO_ROOT=""

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--skip-preflight] [--timeout SECONDS] <repo-root>

Options:
  --skip-preflight    Skip Oracle readiness check.
  --timeout SECONDS   Oracle timeout in seconds (default: 300).
  -h, --help          Show this help message.
EOF
}

json_error() {
  local code="$1"
  local message="$2"
  printf '{"error":"%s","message":"%s"}\n' "$code" "$message" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-preflight)
      SKIP_PREFLIGHT=true
      shift
      ;;
    --timeout)
      if [[ $# -lt 2 ]]; then
        json_error "invalid-args" "Missing value for --timeout"
        exit 1
      fi
      TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      json_error "invalid-args" "Unknown option: $1"
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$REPO_ROOT" ]]; then
        json_error "invalid-args" "Multiple repo roots provided"
        usage >&2
        exit 1
      fi
      REPO_ROOT="$1"
      shift
      ;;
  esac
done

if [[ -z "$REPO_ROOT" ]]; then
  usage >&2
  exit 1
fi

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT" -le 0 ]]; then
  json_error "invalid-timeout" "Timeout must be a positive integer"
  exit 1
fi

if [[ ! -d "$REPO_ROOT" ]]; then
  json_error "invalid-repo-root" "Repo root is not a directory: $REPO_ROOT"
  exit 1
fi

if ! REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"; then
  json_error "invalid-repo-root" "Unable to resolve repo root path"
  exit 1
fi

AGENTS_FILE="$REPO_ROOT/AGENTS.md"
if [[ ! -f "$AGENTS_FILE" ]]; then
  json_error "missing-agents-md" "AGENTS.md not found at repo root"
  exit 1
fi

if [[ "$SKIP_PREFLIGHT" = false ]]; then
  preflight_output=""
  if ! preflight_output=$(DISPLAY=:99 CHROME_PATH=/usr/local/bin/google-chrome-wrapper oracle --wait -p "Reply with only the word READY" 2>&1); then
    json_error "preflight-failed" "Oracle preflight command failed"
    exit 1
  fi
  if ! grep -q "READY" <<<"$preflight_output"; then
    json_error "preflight-failed" "Oracle preflight did not return READY"
    exit 1
  fi
fi

cd "$REPO_ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  json_error "not-a-git-repo" "Repo root is not a git repository"
  exit 1
fi

REPO_NAME="$(basename "$REPO_ROOT")"
AGENTS_CONTENT="$(cat "$AGENTS_FILE")"
CHANGED_FILES="$(git log --format="" --name-only -20 | sort -u | head -30)"
COMMIT_MESSAGES="$(git log --format="- %s" -15)"

count_ext() {
  local ext="$1"
  find . -type f -name "*.${ext}" \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./dist/*" \
    | wc -l | tr -d ' '
}

TS_COUNT="$(count_ext ts)"
JS_COUNT="$(count_ext js)"
PY_COUNT="$(count_ext py)"
GO_COUNT="$(count_ext go)"
RS_COUNT="$(count_ext rs)"
JAVA_COUNT="$(count_ext java)"
RB_COUNT="$(count_ext rb)"

LANGUAGE_COUNTS="$(cat <<EOF
- TypeScript (.ts): ${TS_COUNT}
- JavaScript (.js): ${JS_COUNT}
- Python (.py): ${PY_COUNT}
- Go (.go): ${GO_COUNT}
- Rust (.rs): ${RS_COUNT}
- Java (.java): ${JAVA_COUNT}
- Ruby (.rb): ${RB_COUNT}
EOF
)"

mapfile -t SOURCE_FILES < <(
  find . -maxdepth 3 -type f \
    \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.sh" \) \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./dist/*" \
    -not -name ".env" \
    -not -name ".env.*" \
    | sort | head -40
)

if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
  SOURCE_FILES=("AGENTS.md")
fi

PROMPT="$(cat <<EOF
You are a documentation CRITIC, not a generator.
Your job is to audit AGENTS.md for accuracy, maintainability, and stale/misleading content based on repository evidence.

Return ONLY valid JSON in this exact format:
{
  "suggestions": [
    {
      "id": "short-kebab-id",
      "severity": "low|medium|high",
      "section": "which section this affects",
      "type": "add|correct|flag-stale",
      "suggestion": "what to change",
      "evidence": "why — cite file paths or commit messages"
    }
  ],
  "summary": "1-2 sentence overall assessment"
}

Rules:
- Be strict and evidence-based.
- Do not propose broad rewrites; focus on concrete, actionable corrections.
- If evidence is weak, lower severity and explain uncertainty.
- Use the provided evidence, changed files, commit messages, and file list.
- Output JSON only, no markdown, no prose outside JSON.

Repository evidence:
- Repo name: ${REPO_NAME}
- Changed files (last 20 commits, unique, max 30):
${CHANGED_FILES:-"(none found)"}

- Commit messages (last 15):
${COMMIT_MESSAGES:-"(none found)"}

- Detected languages (file counts):
${LANGUAGE_COUNTS}

AGENTS.md (full content):
<<<AGENTS_MD
${AGENTS_CONTENT}
AGENTS_MD
EOF
)"

FILE_ARGS=(--file "${SOURCE_FILES[@]}")

DISPLAY=:99 CHROME_PATH=/usr/local/bin/google-chrome-wrapper oracle \
  --wait \
  --force \
  -p "$PROMPT" \
  -m gpt-5.2-pro \
  "${FILE_ARGS[@]}" \
  --timeout "$TIMEOUT"
