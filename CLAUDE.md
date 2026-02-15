# CLAUDE.md

> **Documentation is in AGENTS.md** - This file contains Claude-specific settings only.
> For project documentation, architecture, and conventions, see [AGENTS.md](./AGENTS.md).

## Overview

Recursive AGENTS.md generator with integrated GPT 5.2 Pro critique. Generates documentation using parallel subagents, then automatically sends to GPT for independent review. Non-controversial improvements are applied silently; significant changes prompt for approval.

## GPT Review (via Oracle)

After generating/updating AGENTS.md, interdoc sends docs to GPT 5.2 Pro for critique.

- Requires Oracle CLI and active ChatGPT session
- Auto-skips if Oracle unavailable (never blocks)
- Non-controversial changes applied silently
- Significant changes prompt for approval

## Claude-Specific Settings

When working on this repo, Claude should:

- **Remind user to bump version** after committing changes to SKILL.md or hooks — use `/interpub:release <version>` or `scripts/bump-version.sh <version>`
- **Update the marketplace** — both tools above handle this automatically
- Use the Read tool instead of cat for file operations
- Prefer Edit tool over sed/awk for file modifications

## Workflow Reminders

After pushing changes to interdoc:
1. Update `~/interagency-marketplace/.claude-plugin/marketplace.json`
2. Commit and push marketplace changes
3. Run `claude plugin marketplace update interagency-marketplace`
4. Run `claude plugin update interdoc@interagency-marketplace`

## See Also

- [AGENTS.md](./AGENTS.md) - Full project documentation, architecture, development guide
- [README.md](./README.md) - User-facing installation and usage guide
- [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) - Test cases from splinterpeer analysis
