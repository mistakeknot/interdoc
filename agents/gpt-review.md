# GPT Review Phase

After generation/update, interdoc sends AGENTS.md to GPT 5.2 Pro via Oracle for independent critique.

## How It Works

1. Pre-flight check verifies Oracle session
2. Gathers evidence (git changes, commit messages, detected languages)
3. Sends AGENTS.md + source files to GPT with critic prompt
4. Parses structured JSON suggestions
5. Classifies by significance:
   - **Non-controversial** (auto-applied): low severity, additive suggestions
   - **Significant** (user-prompted): high severity, corrections, 3+ suggestions

## Oracle Dependencies

- Oracle CLI installed (`npm i -g @steipete/oracle`)
- Active ChatGPT session (X11 stack: Xvfb on :99, Chrome)
- Environment: `DISPLAY=:99 CHROME_PATH=/usr/local/bin/google-chrome-wrapper`

## Helper Scripts

- `hooks/tools/oracle-review.sh` — Sends AGENTS.md to GPT for critique
- `hooks/tools/sanitize-review.sh` — Strips code fences, citation artifacts
- `hooks/tools/secret-scan.sh` — Filters dangerous files before Oracle upload

## Troubleshooting

- **Oracle session expired:** Run `oracle-login` via NoVNC, complete Cloudflare check
- **X11 not running:** Check `pgrep -f "Xvfb :99"`, restart if needed
- **Review skipped:** Normal if Oracle unavailable — generation still works
