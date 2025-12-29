# AGENTS.md

> Cross-AI documentation for Interdoc. Works with Claude Code, Codex CLI, and other AI coding tools.

## Overview

**Interdoc** is a Claude Code plugin that generates and maintains AGENTS.md documentation using parallel subagents. It analyzes project structure, spawns agents per directory, and consolidates into coherent documentation.

**Why AGENTS.md?** Claude Code reads both AGENTS.md and CLAUDE.md, but AGENTS.md is the cross-AI standard that also works with Codex CLI and other AI coding tools.

**Plugin Type:** Claude Code skill plugin
**Plugin Namespace:** `interdoc` (from interagency-marketplace)
**Current Version:** 4.3.0

## Repository Structure

```
/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata and version (source of truth)
├── hooks/
│   ├── hooks.json           # Hook configuration
│   ├── check-updates.sh     # SessionStart hook
│   └── check-commit.sh      # PostToolUse hook
├── skills/
│   └── interdoc/
│       └── SKILL.md         # Main skill definition
├── docs/
│   ├── plans/               # Design documents
│   └── TEST_PLAN.md         # Test cases from splinterpeer analysis
├── README.md                # User-facing documentation
├── CLAUDE.md                # Claude-specific settings only
└── AGENTS.md                # This file - cross-AI documentation
```

## The Skill

| Skill | Trigger | Use Case |
|-------|---------|----------|
| `interdoc` | Natural language or hooks | Generate/update AGENTS.md documentation |

> **Note:** This is a Claude Code plugin skill, invoked via natural language (e.g., "generate documentation for this project"). It is NOT a slash command.

## Key Features

- **Parallel subagents**: Spawns agents per directory for fast analysis
- **Incremental updates**: Appends new content, preserves existing documentation
- **CLAUDE.md harmonization**: Migrates docs from CLAUDE.md → AGENTS.md
- **Unified diff previews**: Shows actual diffs before applying
- **JSON schema output**: Subagents return structured JSON with sentinel markers
- **Git-aware**: Uses commit messages and diffs for update context
- **Scalability guardrails**: Concurrency limits, batch processing for large repos

## Hooks

| Hook | Trigger | Threshold |
|------|---------|-----------|
| `check-updates.sh` | SessionStart | No AGENTS.md, 7+ days old, or 10+ commits |
| `check-commit.sh` | PostToolUse | 15+ commits since last AGENTS.md update |

**Hook improvements (v4.3.0):**
- Always operate from repo root (fixes subdirectory invocation)
- Per-repo state in `.git/interdoc/` (no cross-repo collision)
- HEAD-tracking instead of timing heuristics
- Atomic locking to prevent race conditions

## Development

### This is Documentation-Driven

There is **no source code** to build or test. The "implementation" is the skill documentation and shell scripts.

**To modify behavior:**
- Edit `skills/interdoc/SKILL.md` to change workflows
- Edit `hooks/*.sh` to change trigger logic
- Update `README.md` for user-facing documentation
- Update `.claude-plugin/plugin.json` for metadata/version changes

### Testing Changes

1. Make changes to SKILL.md or hook files
2. Commit and push to GitHub
3. Run `claude plugin update interdoc@interagency-marketplace` to refresh local cache
4. Trigger the skill to verify behavior

See `docs/TEST_PLAN.md` for comprehensive test cases.

## Version Management

**Version is declared in `.claude-plugin/plugin.json` (root level).**

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Bug fix, docs clarification | Patch | 4.3.0 → 4.3.1 |
| New feature, workflow change | Minor | 4.3.0 → 4.4.0 |
| Breaking change | Major | 4.3.0 → 5.0.0 |

### Bump Version

After committing skill changes:

```bash
# 1. Edit plugin.json and increment version
# 2. Commit and push
git add .claude-plugin/plugin.json
git commit -m "Bump version to X.Y.Z"
git push
```

### Update the Marketplace

The plugin is distributed via `interagency-marketplace`. After pushing version changes:

1. Edit `~/interagency-marketplace/.claude-plugin/marketplace.json`
2. Update the `interdoc` entry version
3. Commit and push
4. Refresh local cache:
   ```bash
   claude plugin marketplace update interagency-marketplace
   claude plugin update interdoc@interagency-marketplace
   ```

## Commit Workflow

1. Edit the relevant files (SKILL.md, hooks, etc.)
2. Commit with descriptive message
3. **Bump version in plugin.json**
4. Commit version bump
5. Push both commits
6. **Update ~/interagency-marketplace** with new version
7. Push marketplace changes

## Recent Changes (December 2025)

### v4.3.0 - Splinterpeer Robustness Improvements
- Rewrote hooks with repo-root handling and HEAD-tracking
- Added JSON schema with sentinel markers for subagent output
- Added deterministic CLAUDE.md heading allowlist
- Added scalability guardrails (concurrency limits, batching)
- Fixed find commands for filename safety
- Added comprehensive test plan

### v4.2.0 - CLAUDE.md Harmonization
- Initial CLAUDE.md → AGENTS.md migration feature

### v4.1.0 - Improved Verification and UX
- Better subagent verification before consolidation
- Individual file review option

---

*Last updated: 2025-12-28*
