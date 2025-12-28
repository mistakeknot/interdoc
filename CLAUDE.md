# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

**Interdoc** is a Claude Code plugin that generates and maintains CLAUDE.md documentation using parallel subagents. It analyzes project structure, spawns agents per directory, and consolidates into coherent documentation.

**Plugin Type:** Claude Code skill plugin
**Plugin Namespace:** `interdoc` (from interagency-marketplace)

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
│   └── plans/               # Design documents
├── README.md                # User-facing documentation
└── CLAUDE.md                # This file
```

## The Skill

| Skill | Trigger | Use Case |
|-------|---------|----------|
| `interdoc` | Natural language or hooks | Generate/update CLAUDE.md documentation |

> **Note:** This is a Claude Code plugin skill, invoked via natural language (e.g., "generate documentation for this project"). It is NOT a slash command.

## Version Management (IMPORTANT)

**Version is declared in `.claude-plugin/plugin.json` (root level).**

### When to Bump Version

After committing changes to the skill, bump the version:

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Bug fix, docs clarification | Patch | 3.0.0 → 3.0.1 |
| New feature, workflow change | Minor | 3.0.1 → 3.1.0 |
| Breaking change | Major | 3.1.0 → 4.0.0 |

### How to Bump Version

After committing skill changes:

```bash
# 1. Edit plugin.json and increment version
# 2. Commit and push
git add .claude-plugin/plugin.json
git commit -m "chore: bump version to X.Y.Z"
git push
```

**Claude: When you commit changes to SKILL.md or hooks, remind the user to bump the version or offer to do it automatically.**

## Update the Marketplace (CRITICAL)

The plugin is distributed via `interagency-marketplace`. After pushing version changes here, you **must also update the marketplace**:

```bash
# 1. Update marketplace manifest with new version
cd ~/interagency-marketplace
# Edit .claude-plugin/marketplace.json - update interdoc version and description

# 2. Commit and push marketplace
git add .
git commit -m "chore: bump interdoc to X.Y.Z"
git push
```

### Refresh Local Cache

After pushing both repos:

```bash
claude plugin marketplace update interagency-marketplace
claude plugin update interdoc@interagency-marketplace
```

**Claude: When bumping the version, remind the user to also update the marketplace repo, or offer to do it if `~/interagency-marketplace` exists.**

## Development Notes

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
3. Run `claude plugins update interdoc` to refresh local cache
4. Trigger the skill to verify behavior

## Commit Workflow

When making changes:

1. Edit the relevant files (SKILL.md, hooks, etc.)
2. Commit with descriptive message
3. **Bump version in plugin.json** (patch for docs, minor for features)
4. Commit version bump
5. Push both commits
6. **Update ~/interagency-marketplace** with new version
7. Push marketplace changes
