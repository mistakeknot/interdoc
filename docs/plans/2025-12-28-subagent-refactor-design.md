# Interdoc Subagent Refactor Design

## Overview

Transform Interdoc from a commit-analysis tool into a recursive documentation generator using Claude Code subagents.

**Current state:** Hook-triggered skill that analyzes git commits and suggests CLAUDE.md updates.

**Target state:** Skill that spawns parallel subagents to generate/update CLAUDE.md files across a project, with hooks as simple triggers.

## Core Architecture

### Single skill, two modes

- **Generation mode**: No CLAUDE.md exists → full recursive subagent pass
- **Update mode**: CLAUDE.md exists → analyze changes, spawn subagents only for affected directories

### Invocation

- **Manual**: `/interdoc` command
- **Auto**: SessionStart hook triggers when no CLAUDE.md exists OR commit thresholds met

### Subagent structure

```
Root Agent (main session)
  ├─ Analyzes project structure
  ├─ Identifies directories that warrant documentation
  ├─ Spawns subagents in parallel (one per directory)
  │     ├─ Subagent A: /src/api/
  │     ├─ Subagent B: /src/core/
  │     └─ Subagent C: /packages/shared/
  ├─ Collects subagent outputs
  ├─ Consolidation pass (dedup, harmonize, cross-cutting concerns)
  └─ Creates/updates CLAUDE.md files + AGENTS.md redirects
```

### Subagent decision criteria

Each subagent decides if its directory warrants a CLAUDE.md:
- Has 5+ source files, OR
- Has a package manifest (package.json, Cargo.toml, etc.), OR
- Contains complex logic worth documenting

If not warranted, subagent returns summary for parent to incorporate.

## Subagent Behavior

### What each subagent does

1. **Explore its directory** - Read source files, configs, any existing README
2. **Extract agent-useful info:**
   - Purpose of this directory/package
   - Key files and what they do
   - Architecture patterns (how components connect)
   - Conventions (naming, structure, patterns to follow)
   - Dependencies (what this code relies on)
   - Gotchas (non-obvious behavior, known issues from comments/TODOs)
   - Build/test commands if applicable

3. **Decide: CLAUDE.md here or summarize up?**
   - If warranted → draft a CLAUDE.md for this directory
   - If not → return a summary paragraph for parent to incorporate

4. **Return structured output:**
```json
{
  "path": "/src/api/",
  "warrants_claude_md": true,
  "claude_md_content": "...",
  "summary": "...",
  "patterns_discovered": ["..."],
  "cross_cutting_notes": ["..."]
}
```

### Subagent prompt template

```
You are documenting the directory: {path}

Analyze the code and extract information useful for coding agents:
- What is this directory's purpose?
- What are the key files and their roles?
- What patterns/conventions should agents follow?
- What gotchas or non-obvious behavior exists?

If this directory is complex enough (5+ source files, has package manifest,
or contains significant logic), create a CLAUDE.md. Otherwise, return a
summary for the parent directory's CLAUDE.md.
```

## Consolidation Pass

### What the root agent does after collecting subagent outputs

1. **Deduplicate patterns** - If multiple subagents discovered the same convention, mention it once in root CLAUDE.md

2. **Harmonize terminology** - Ensure consistent naming across subagent outputs

3. **Identify cross-cutting concerns** - Things that span directories:
   - Shared types/interfaces
   - Common error handling patterns
   - Data flow between packages
   - Build/deploy pipeline

4. **Build root CLAUDE.md structure:**
```markdown
# CLAUDE.md

## Overview
[What this project does - synthesized from subagent summaries]

## Architecture
[How the pieces fit together - cross-cutting concerns]

## Directory Structure
[Map of key directories with one-line descriptions]
- `/src/api/` - REST API layer (has own CLAUDE.md)
- `/src/core/` - Business logic
- `/packages/shared/` - Shared utilities (has own CLAUDE.md)

## Conventions
[Project-wide patterns - deduplicated from subagents]

## Development
[Build, test, run commands - consolidated]
```

5. **Write files:**
   - Root CLAUDE.md
   - Per-directory CLAUDE.md (where warranted)
   - AGENTS.md redirects next to each CLAUDE.md

6. **Commit all documentation**

## Hook Integration

### Simplified hooks that just invoke the skill

**SessionStart hook:**
```bash
#!/bin/bash
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

if [ ! -f "CLAUDE.md" ]; then
    echo "No CLAUDE.md found. Use /interdoc to generate documentation for this project."
    exit 0
fi

CLAUDE_UPDATE_TIME=$(git log -1 --format=%ct CLAUDE.md 2>/dev/null)
COMMITS_SINCE=$(git log --since="@$CLAUDE_UPDATE_TIME" --oneline | wc -l)

if [ "$COMMITS_SINCE" -ge 3 ]; then
    echo "There are $COMMITS_SINCE commits since CLAUDE.md was last updated. Use /interdoc to update documentation."
fi
```

**PostToolUse hook:** Same pattern, 10+ commit threshold.

**Key change:** Hooks suggest invoking `/interdoc` rather than injecting detailed prompts. The skill handles everything.

## Update Mode (Ongoing Maintenance)

### When CLAUDE.md exists and commits have accumulated

1. **Detect affected directories** - Analyze commits to find changed directories:
   ```bash
   git diff --name-only @<last_claude_update> HEAD
   ```

2. **Spawn targeted subagents** - Only for directories with changes

3. **Subagent behavior in update mode:**
   - Read existing CLAUDE.md (if present)
   - Analyze what changed in commits
   - Propose additions/modifications (not full rewrite)
   - Flag if something documented is now stale

4. **Consolidation in update mode:**
   - Merge updates into existing CLAUDE.md structure
   - Preserve user customizations
   - Only touch sections relevant to changes

5. **Present diff for approval:**
   ```
   Found 2 directories with changes:

   1. /src/api/ - New authentication middleware
   2. /src/core/ - Refactored validation logic

   Would you like to review suggested updates?
   ```

## File Structure

```
interdoc/
├── .claude-plugin/
│   └── plugin.json          # Update version/description
├── hooks/
│   ├── hooks.json            # Same structure
│   ├── check-updates.sh      # Simplified - suggests /interdoc
│   └── check-commit.sh       # Simplified - suggests /interdoc
├── skills/
│   └── interdoc/
│       └── SKILL.md          # Rewritten for subagent approach
└── README.md                 # Updated docs
```

## Implementation Steps

1. Rewrite SKILL.md with new subagent-based workflow
2. Simplify hook scripts to just suggest `/interdoc`
3. Update plugin.json version and description
4. Update README.md with new usage patterns
5. Test generation mode on a fresh project
6. Test update mode on a project with existing CLAUDE.md
