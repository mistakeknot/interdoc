# CLAUDE.md

> **Documentation is in AGENTS.md** - This file contains Claude-specific settings only.
> For project documentation, architecture, and conventions, see [AGENTS.md](./AGENTS.md).

## Overview

Recursive AGENTS.md generator. Generates documentation using parallel subagents, then consolidates into coherent project documentation.

## Claude-Specific Settings

When working on this repo, Claude should:

- Use the Read tool instead of cat for file operations
- Prefer Edit tool over sed/awk for file modifications
- After behavioral changes, publish via `scripts/bump-version.sh` (see root `agents/plugin-publishing.md`)

## See Also

- [AGENTS.md](./AGENTS.md) - Full project documentation, architecture, development guide
- [README.md](./README.md) - User-facing installation and usage guide
- [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) - Test cases from splinterpeer analysis
