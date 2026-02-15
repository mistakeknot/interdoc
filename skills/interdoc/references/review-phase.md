# Review Phase (GPT Critique)

After generating or updating AGENTS.md, interdoc optionally sends the documentation to GPT 5.2 Pro via Oracle for independent critique. This catches blind spots that self-review misses.

## When Review Runs

- **Auto-trigger (default):** After every generation or update, IF Oracle is available
- **Skip conditions:** Oracle not installed, Oracle session expired, user passed `--no-review` or said "no review" / "skip review" / "no GPT"
- **Manual trigger:** User says "review AGENTS.md", "critique docs", "get GPT review"

## Pre-flight Check

Before spending time on review, verify Oracle session:

1. Run: `DISPLAY=:99 CHROME_PATH=/usr/local/bin/google-chrome-wrapper oracle --wait -p "Reply with only the word READY"`
2. If output contains "READY" -> proceed
3. If fails -> skip review, emit warning: "Oracle session unavailable -- skipping GPT review. Run `oracle-login` to fix."

## Evidence Gathering

Collect codebase context for the review prompt:

1. **Changed files** since last AGENTS.md update (from git)
2. **Recent commit messages** (last 15)
3. **Detected languages** (from file extensions)
4. **Source files** for Oracle attachment (max 40, filtered through secret-scan.sh)

## Review Prompt Structure

The prompt instructs GPT to act as a **critic, not a generator**:

```
Role: CRITIC reviewing AGENTS.md for [languages] project "[name]"
Context: Full AGENTS.md content
Evidence: Changed files + commit messages
Task: Return JSON with suggestions array + summary
Rules: Evidence-backed, max 10, specific text
```

See `hooks/tools/oracle-review.sh` for the exact prompt template.

## Processing GPT Output

1. Pipe Oracle output through `hooks/tools/sanitize-review.sh`
2. Parse structured JSON: `{suggestions: [...], summary: "..."}`
3. Classify suggestions by significance:
   - **Significant:** severity=high, or type=correct (factual errors), or 3+ suggestions
   - **Non-controversial:** severity=low, type=add (missing info), single suggestion

## Applying Results

### Non-controversial changes (apply silently):
- Single low-severity "add" suggestion -> append to relevant section
- Summary says "documentation is accurate" with 0-1 minor suggestions

### Significant changes (prompt user):
Show the suggestions grouped by section with severity badges, then ask:

```
GPT 5.2 Pro found N suggestions:
- [HIGH] Section: suggestion text
- [MED] Section: suggestion text

[A] Apply all / [S] Show details / [R] Review individually / [X] Skip
```

## State Tracking

Store review metadata in `.git/interdoc/last-review.json`:

```json
{
  "reviewedAt": "2026-02-13T...",
  "reviewedCommit": "abc123",
  "suggestionCount": 3,
  "appliedCount": 2,
  "skippedCount": 1
}
```

This prevents re-reviewing unchanged documentation.

## Timeout & Error Handling

- Oracle timeout: 10 minutes (configurable)
- If Oracle fails mid-review: save partial output, continue without review
- If JSON parse fails: save raw output to `.git/interdoc/review-raw.txt`, warn user
- Never block the generate/update workflow -- review is best-effort

## Secret Scanning

Before sending files to Oracle, pipe the file list through `hooks/tools/secret-scan.sh`:
- Filters out `.env*`, `*.pem`, `*.key`, credential files
- Scans content for API keys, AWS credentials, private keys, tokens
- Safe files proceed; dangerous files are silently excluded with a stderr warning

## Suggestion JSON Schema

```json
{
  "suggestions": [
    {
      "id": "short-kebab-id",
      "severity": "low|medium|high",
      "section": "which section this affects",
      "type": "add|correct|flag-stale",
      "suggestion": "what to change (specific, include exact text)",
      "evidence": "why -- cite file paths or commit messages"
    }
  ],
  "summary": "1-2 sentence overall assessment"
}
```

- `add` = new content missing from docs
- `correct` = existing content is wrong
- `flag-stale` = content may be outdated
