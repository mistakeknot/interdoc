# Interdoc

**Recursive AGENTS.md generator using parallel subagents**

Interdoc generates and maintains AGENTS.md documentation for your projects. It spawns parallel subagents to analyze each directory, then consolidates their findings into coherent documentation that helps coding agents understand your codebase.

**Why AGENTS.md?** Claude Code reads both AGENTS.md and CLAUDE.md, but AGENTS.md is the cross-AI standard that also works with Codex CLI and other AI coding tools. Using AGENTS.md as the primary format ensures maximum compatibility.

## Features

- **Parallel subagents**: Spawns agents per directory for fast analysis
- **Incremental updates**: Appends new content, preserves existing documentation
- **CLAUDE.md harmonization**: Migrates docs from CLAUDE.md → AGENTS.md, slims CLAUDE.md to settings only
- **Unified diff previews**: Shows actual diffs before applying (not just summaries)
- **Individual file review**: Step through files one by one with [R]eview option
- **Subagent verification**: Confirms files were created before committing
- **Progress reporting**: Shows subagent status during execution
- **Smart monorepo scoping**: Offers depth control for large projects (100+ files)
- **Git-aware**: Uses commit messages and diffs for context in updates
- **Consolidation**: Deduplicates patterns, identifies cross-cutting concerns
- **Dry-run validation**: Validates structured output before applying
- **Cross-AI compatible**: AGENTS.md works with Claude Code, Codex CLI, and other AI tools

## Installation

### From Marketplace

```bash
# Add the interagency marketplace (if not already added)
/plugin marketplace add mistakeknot/interagency-marketplace

# Install Interdoc
/plugin install interdoc
```

### Manual Installation

```bash
git clone https://github.com/mistakeknot/interdoc.git
cd interdoc
/plugin install .
```

### Codex CLI (manual)

Fetch and follow the instructions in `.codex/INSTALL.md`:

```bash
curl -fsSL https://raw.githubusercontent.com/mistakeknot/interdoc/main/.codex/INSTALL.md | sed -n '1,200p'
```

To update later, re-run the install command from that file.

## Usage

### Manual

Ask Claude to generate or update documentation:

```
"generate documentation for this project"
"create AGENTS.md"
"update AGENTS.md"
"document this codebase"
```

Tip: In Claude Code, you can say "List all available Skills" to see interdoc.

The skill automatically detects which mode to use:
- **No AGENTS.md exists** → Generation mode (full recursive pass)
- **AGENTS.md exists** → Update mode (incremental changes only)

### Optional Modes

You can request additional behaviors via phrases in your prompt:

- **Change-set update**: "update AGENTS.md for changed files only"
- **Coverage report**: "doc coverage" or "coverage report"
- **Style lint**: "lint AGENTS.md" or "doc lint"

### Hooks (Disabled by Default)

Interdoc does not ship with hooks enabled. Manual invocation is the default.

### Claude Code Subagents (Optional)

For faster directory analysis in Claude Code, Interdoc includes a specialized
subagent at `.claude/agents/interdocumentarian.md`. When available, the main
agent can dispatch one subagent per directory and consolidate the JSON outputs.

### Dry Run (Preview Only)

Add "dry run" (or "preview only", "no write") to your request to generate a
summary + diff preview without writing files. To apply later without re-analysis,
say "apply last preview" (valid until HEAD changes).

### Advisory Commit Hook (Optional)

You can enable a non-blocking post-commit reminder to update AGENTS.md:

```bash
./hooks/git/install-post-commit.sh
```

This hook never blocks commits; it only prints a reminder when AGENTS.md may be stale.

### Audit Script (Optional)

Run a quick coverage + lint pass locally:

```bash
./hooks/tools/interdoc-audit.sh
```

## How It Works

### Generation Mode

1. **Analyze structure** - Find directories with source files and package manifests
2. **Scope selection** - For large projects, offer: top-level only, existing AGENTS.md, full recursive, or custom
3. **Spawn subagents** - One per directory, running in parallel
4. **Each subagent** returns structured output:
   - Purpose, key files, architecture, conventions, gotchas
   - Decision on whether directory warrants its own AGENTS.md
5. **Consolidate** - Deduplicate patterns, create cross-references
6. **Diff preview** - Show proposed files before writing
7. **Write and commit** - Apply immediately unless dry-run is requested

### Update Mode

1. **Detect changes** - Git diff since last AGENTS.md update
2. **Skip up-to-date** - Directories where AGENTS.md is newer than source changes
3. **Spawn targeted subagents** - With git context (diffs, commit messages)
4. **Incremental proposals** - ADDITIONS, MODIFICATIONS, DELETIONS (not full rewrites)
5. **Diff preview** - Show exact changes in unified diff format
6. **Apply updates** - Preserve existing content, append new sections (unless dry-run)

## Example

### New Project

```
User: generate documentation for this project

Claude: I'll generate AGENTS.md documentation for this project.

Analyzing project structure...
Found 127 source files across 12 directories.

This is a large project. How would you like to scope?
1. Top-level only - Document root and 4 package directories
2. Full recursive - Analyze all 12 directories
3. Custom - Specify directories

User: 1

Claude: Spawning 4 subagents...

Proposed changes:

📁 /AGENTS.md (new)
+# AGENTS.md
+## Overview
+[preview...]

📁 /packages/core/AGENTS.md (new)
+# Core Package
+[preview...]

Apply these changes? (yes/no/review)

User: yes

Claude: Created 3 AGENTS.md files.
Committed: "Generate AGENTS.md documentation"
```

### Existing Project

```
User: update AGENTS.md

Claude: AGENTS.md exists. Analyzing changes...

Last updated: 5 days ago
Commits since: 47
Changed directories: 3

Proposed updates:

📁 /packages/ui-web/src/hooks/AGENTS.md
```diff
@@ -38,6 +38,12 @@
+## Simulation Event Hooks (December 2025)
+
+### useSectorShock
+Tracks supply chain disruption signals
```

📁 /packages/core/src/infrastructure/AGENTS.md
```diff
@@ -100,6 +100,8 @@
+### December 2025 - WorkerPool DI
+- Supports dependency injection for testing
```

Apply these updates? [A]pply all / [R]eview / [S]kip

User: A

Claude: Applied 2 updates.
Committed: "Update AGENTS.md documentation"
```

## CLAUDE.md Harmonization

If your project has both CLAUDE.md and AGENTS.md, Interdoc can consolidate them:

1. **Analyzes CLAUDE.md** - Identifies documentation vs Claude-specific settings
2. **Migrates documentation** - Moves project docs to AGENTS.md
3. **Slims CLAUDE.md** - Leaves only Claude-specific settings (model prefs, tool restrictions)
4. **Adds pointer** - CLAUDE.md now points to AGENTS.md for documentation

**Before:**
```
CLAUDE.md (150 lines) - Mixed docs + settings
AGENTS.md (200 lines) - Some overlap with CLAUDE.md
```

**After:**
```
CLAUDE.md (15 lines) - Claude settings only, points to AGENTS.md
AGENTS.md (280 lines) - All documentation consolidated
```

## Design Principles

1. **AGENTS.md as primary** - All documentation in AGENTS.md (cross-AI compatible)
2. **CLAUDE.md harmonization** - Slim CLAUDE.md to Claude-specific settings only
3. **Incremental updates** - Append and modify, don't replace entire files
4. **Actual diff preview** - Show real unified diffs, not just summaries
5. **Individual review option** - Let users step through files one by one
6. **Verify subagent writes** - Check git status after subagents complete
7. **Preserve customizations** - Never remove user's manual additions
8. **Parallel execution** - Spawn subagents concurrently for speed
9. **Progress reporting** - Show subagent status during execution
10. **Smart scoping** - Offer depth control for large monorepos
11. **Git-aware** - Use diffs and commit messages for context

## Directory Structure

```
interdoc/
├── .claude-plugin/
│   └── plugin.json         # Plugin metadata (version source of truth)
├── hooks/
│   ├── hooks.json          # Hook configuration
│   ├── check-updates.sh    # SessionStart hook
│   └── check-commit.sh     # PostToolUse hook
├── skills/
│   └── interdoc/
│       └── SKILL.md        # Main skill definition
└── README.md
```

## License

MIT License

## Author

MK (mistakeknot@vibeguider.org)
