---
name: interdoc
description: Generate or update AGENTS.md documentation using parallel subagents. Triggers automatically via hooks or when user asks to generate/update documentation.
---

# Interdoc: Recursive Documentation Generator

## Purpose

Generate and maintain AGENTS.md files across a project using parallel subagents. Each subagent documents a directory, and the root agent consolidates into coherent project documentation.

**Why AGENTS.md?** Claude Code reads both AGENTS.md and CLAUDE.md, but AGENTS.md is the cross-AI standard that also works with Codex CLI and other AI coding tools. Using AGENTS.md as the primary format ensures maximum compatibility.

## When to Use

**Manual invocation:**
- User asks: "generate documentation", "create AGENTS.md", "document this project", "update AGENTS.md"

**Automatic triggers (via hooks):**
- SessionStart: No AGENTS.md exists, or 7+ days since last update, or 10+ commits since last update
- PostToolUse: 15+ commits accumulated mid-session

## Mode Detection

The skill automatically detects which mode to use:

- **No AGENTS.md exists** → Generation mode (full recursive pass)
- **AGENTS.md exists** → Update mode (targeted pass on changed directories)

---

# Generation Mode Workflow

## Step 1: Analyze Project Structure

Explore the project to identify directories that may warrant documentation:

```bash
# Find directories with source files
find . -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) | xargs dirname | sort -u

# Find package manifests
find . -name "package.json" -o -name "Cargo.toml" -o -name "go.mod" -o -name "pyproject.toml" -o -name "requirements.txt"

# Find existing AGENTS.md files (prioritize these for updates)
find . -name "AGENTS.md" -type f
```

Build a list of directories to document. Include:
- Root directory (always)
- Directories with package manifests
- Directories with existing AGENTS.md files (high priority)
- Directories with 5+ source files
- Major structural directories (src/, lib/, packages/, apps/)

### Scoping for Large Monorepos

For projects with 100+ files or deep nesting, offer the user a choice:

```
This is a large project. How would you like to scope the documentation?

1. Top-level only - Document root and immediate package directories
2. Existing AGENTS.md - Only update directories that already have AGENTS.md
3. Full recursive - Analyze all directories (may spawn many subagents)
4. Custom - Specify directories to include/exclude
```

## Step 2: Spawn Subagents

For each directory identified, spawn a subagent using the Task tool.

**Spawn subagents in parallel** using multiple Task tool calls in a single message.

**Progress tracking:** After spawning, report progress to the user:
```
Spawning 6 subagents...
- packages/ui-web/src/components (14 subdirs)
- packages/api/src (3 subdirs)
- src-tauri/src (8 subdirs)
- scripts (16 subdirs)
- packages/debug-tools
- packages/shadow-work-mcp

⏳ Waiting for subagents to complete...
```

### Subagent Prompt Template (Generation Mode)

```
You are documenting the directory: {path}

Your job is to analyze the code and extract information useful for coding agents.

**Explore the directory:**
- Read source files to understand what they do
- Check for README.md, package.json, or other metadata
- Look at file structure and naming patterns

**Extract and document:**
1. Purpose - What does this directory/package do?
2. Key files - What are the important files and their roles?
3. Architecture - How do components connect? What's the data flow?
4. Conventions - Naming patterns, code style, structural patterns
5. Dependencies - What does this code depend on?
6. Gotchas - Non-obvious behavior, known issues, TODOs worth noting
7. Commands - Build, test, run commands if applicable

**Decide if this directory warrants its own AGENTS.md:**
- YES if: 5+ source files, has package manifest, or contains significant complexity
- NO if: Simple, few files, or just utilities

**Return your response in this STRUCTURED format:**

DIRECTORY: {path}
WARRANTS_AGENTS_MD: true/false
SUMMARY: [One paragraph summary for parent AGENTS.md]

PATTERNS_DISCOVERED:
- pattern: [Pattern name]
  description: [What it is]
  examples: [File or code examples]

CROSS_CUTTING_NOTES:
- [Things that affect other parts of the codebase]

AGENTS_MD_SECTIONS: (only if WARRANTS_AGENTS_MD is true)
- section: "Purpose"
  content: |
    [Content for this section]

- section: "Key Files"
  content: |
    [Content for this section]

- section: "Architecture"
  content: |
    [Content for this section]

- section: "Conventions"
  content: |
    [Content for this section]

- section: "Gotchas"
  content: |
    [Content for this section]
```

## Step 3: Verify Subagent Results

After all subagents complete, verify their work before consolidation:

```bash
# Check which files were actually created/modified
git status --short | grep AGENTS.md
```

**Verification checklist:**
- Count new files (lines starting with `??`)
- Count modified files (lines starting with `M`)
- Compare against expected counts from subagent reports
- If discrepancy, investigate which subagent failed to write

**Report to user:**
```
✅ Subagents complete (6/6)

Verification:
- Expected: 20 new, 15 updated
- Actual: 20 new, 15 updated ✓

Proceeding to consolidation...
```

If verification fails:
```
⚠️ Subagent verification failed

Expected 20 new files, found 18.
Missing:
- packages/api/src/routes/AGENTS.md
- src-tauri/src/economy/data/AGENTS.md

[R]etry failed subagents / [C]ontinue anyway / [A]bort
```

## Step 4: Collect and Consolidate

After verification, consolidate subagent outputs:

**Deduplicate patterns:**
- If multiple subagents report the same convention, include it once in root AGENTS.md
- Pick the clearest description
- Note which directories share the pattern

**Harmonize terminology:**
- Ensure consistent naming (don't mix "API layer" and "backend services")
- Use terminology from existing README if present

**Identify cross-cutting concerns:**
- Shared types/interfaces used across directories
- Common error handling patterns
- Data flow between packages
- Build/deploy pipeline that spans the project

**Create cross-references:**
- Link related updates (e.g., "core infrastructure change enables new UI hooks")
- Note dependencies between documented directories

## Step 5: Build Root AGENTS.md

Create the root AGENTS.md with this structure:

```markdown
# AGENTS.md

## Overview

[What this project does - synthesized from subagent summaries and any existing README]

## Architecture

[How the pieces fit together - cross-cutting concerns, data flow]

## Directory Structure

[Map of key directories with one-line descriptions]
- `/src/api/` - REST API layer (has own AGENTS.md)
- `/src/core/` - Business logic
- `/packages/shared/` - Shared utilities (has own AGENTS.md)

## Conventions

[Project-wide patterns - deduplicated from subagents]

## Development

[Build, test, run commands - consolidated from subagents]

## Gotchas

[Project-wide gotchas and known issues]
```

## Step 6: Diff Preview with Individual Review Option

Before writing any files, show the user **actual unified diffs** (not just summaries):

**For new files**, show first 20 lines:
```
📁 /src/api/AGENTS.md (new file, 45 lines)
```diff
+# API Layer
+
+## Purpose
+REST API endpoints for the simulation game.
+
+## Key Files
+| File | Purpose |
+|------|---------|
+| server.ts | Express app setup |
+| routes/*.ts | Route handlers |
+
+## Architecture
+- Express middleware stack
+- Route mounting under /api/
+...
```
[truncated, 25 more lines]
```

**For updated files**, show actual unified diff:
```
📁 /packages/ui-web/AGENTS.md (modified)
```diff
@@ -17,6 +17,12 @@
 ## Data & Utilities

 - `src/data` centralizes country mappings...
+- The single source of truth for country mappings is now `data/country-shadow-map.json`
+
+## Tauri Integration
+
+- Tauri services under `src/services/tauri/` handle Rust/TypeScript bridging
+- Use `deltaClient.ts` as the single source of truth for simulation state
```
```

**Approval options:**
```
Apply these changes?
  [A] Apply all (17 new, 27 updated)
  [R] Review individually (step through each file)
  [S] Skip for now
  [E] Edit suggestions (modify before applying)
```

**If user selects [R] Review individually:**
```
📁 /src/api/AGENTS.md (new file)
[shows full diff]

Apply this file? [y]es / [n]o / [e]dit / [q]uit review
```

## Step 7: Write Files

After user approval, for each directory where a subagent indicated WARRANTS_AGENTS_MD: true:
1. Write the AGENTS.md file

Write root AGENTS.md.

## Step 8: Commit

```bash
git add -A "*.md"
git commit -m "Generate AGENTS.md documentation

Created documentation for:
- [list directories with AGENTS.md]

Generated by Interdoc"
```

---

# Update Mode Workflow

## Step 1: Detect Changes

Find what changed since last AGENTS.md update:

```bash
# Get the commit hash when AGENTS.md was last modified
AGENTS_UPDATE_COMMIT=$(git log -1 --format=%H AGENTS.md)

# Get the timestamp
AGENTS_UPDATE_TIME=$(git log -1 --format=%ct AGENTS.md)

# Calculate days since update
CURRENT_TIME=$(date +%s)
DAYS_SINCE=$(( (CURRENT_TIME - AGENTS_UPDATE_TIME) / 86400 ))

# Get changed files since last update
git diff --name-only "$AGENTS_UPDATE_COMMIT" HEAD

# Count commits since update
COMMITS_SINCE=$(git rev-list --count "$AGENTS_UPDATE_COMMIT"..HEAD)
```

Group changed files by directory.

### Skip Up-to-Date Directories

For each directory with an AGENTS.md:
```bash
# Check if directory's AGENTS.md is newer than source changes
DIR_AGENTS_TIME=$(git log -1 --format=%ct "$DIR/AGENTS.md")
LATEST_SOURCE_TIME=$(git log -1 --format=%ct -- "$DIR/*.ts" "$DIR/*.js" "$DIR/*.py")

if [ "$DIR_AGENTS_TIME" -gt "$LATEST_SOURCE_TIME" ]; then
    # Skip - AGENTS.md is up to date
fi
```

## Step 2: Spawn Targeted Subagents

Only spawn subagents for directories with changes. Use the enhanced prompt with git context:

### Subagent Prompt Template (Update Mode)

```
You are updating documentation for: {path}

## Git Context

**Commits since last AGENTS.md update:** {commit_count}
**Days since last update:** {days_since}

**Changed files:**
{list of changed files}

**Recent commit messages:**
{recent commit messages, most recent first}

**File diffs (summary):**
{abbreviated diffs showing what changed - additions/deletions/modifications}

## Current AGENTS.md Content

{existing AGENTS.md content if present}

## Your Task

Analyze the changes and propose INCREMENTAL updates. Do NOT rewrite the entire file.

**Return your response in this STRUCTURED format:**

DIRECTORY: {path}
CHANGES_SUMMARY: [Brief description of what changed]
UPDATES_NEEDED: true/false

ADDITIONS: (new sections or items to add)
- section: "Recent Updates (Month Year)"
  position: "after:Gotchas"  # or "before:X" or "end"
  content: |
    ### New Feature Name
    - Description of what was added
    - Usage example if applicable

- section: "Key Files"
  action: "append"
  items:
    - "newFile.ts - Description of what it does"
    - "anotherNew.ts - Description"

MODIFICATIONS: (changes to existing sections)
- section: "Architecture"
  action: "update"
  find: "Old description text"
  replace: "Updated description text"

- section: "File Organization"
  action: "append_to_list"
  items:
    - "newHook.ts"
    - "newComponent.ts"

DELETIONS: (only if something was removed from codebase)
- section: "Deprecated Features"
  reason: "Feature X was removed in commit abc123"

STALE_CONTENT: (existing documentation that is now incorrect)
- section: "Architecture"
  issue: "Still references old pattern X, but code now uses Y"
  suggestion: "Update to reflect new pattern"
```

## Step 3: Present for Approval with Diff Preview

Show the user what updates are proposed in diff format:

```
Found changes in 2 directories:

📁 /src/api/AGENTS.md
```diff
@@ -45,6 +45,18 @@
 ## Gotchas
 - Rate limiting applies to all endpoints

+## Recent Updates (December 2025)
+
+### Authentication Middleware
+- New JWT validation in middleware/auth.ts
+- Configurable via AUTH_* env vars
+
+### Rate Limiting
+- Added rate limiting middleware
+- Configurable via RATE_LIMIT_* env vars
```

📁 /AGENTS.md (root)
```diff
@@ -12,6 +12,7 @@
 ## Architecture

 - API layer handles HTTP requests
+- Authentication middleware validates JWTs before route handlers
 - Core business logic in /src/core
```

Apply these updates?
- [A] Apply all
- [R] Review individually
- [S] Skip for now
- [E] Edit suggestions
```

## Step 4: Apply Approved Updates

For each approved update:
1. Read existing AGENTS.md
2. Apply ONLY the specified modifications (preserve other sections)
3. Validate the result is valid markdown
4. Write updated file

**Preservation rules:**
- Never remove sections unless explicitly in DELETIONS
- Append new content rather than replacing when possible
- Keep user's custom formatting and additions
- Add "Last Updated: YYYY-MM-DD" at the bottom

## Step 5: Commit

```bash
git add -A "*.md"
git commit -m "Update AGENTS.md documentation

Updated:
- [list of changes by directory]

Generated by Interdoc"
```

---

# Consolidation Pass

After collecting all subagent outputs, the root agent performs consolidation:

## Deduplication

```
Patterns found across multiple directories:
- "TypeScript strict mode" mentioned in: /src/api, /src/core, /packages/shared
  → Move to root AGENTS.md "Conventions" section
  → Remove from individual AGENTS.md files

- "Jest for testing" mentioned in: /src/api, /src/core
  → Keep in root, reference from subdirectories
```

## Cross-Reference Generation

```
Related updates detected:
- /packages/core/infrastructure added "WorkerPool DI pattern"
- /packages/ui-web/hooks added "useSectorShock hook"
- These are related: UI hook uses the core infrastructure

→ Add to root AGENTS.md:
  "The useSectorShock hook (ui-web) leverages the WorkerPool DI pattern (core/infrastructure)"
```

## Recent Changes Summary

For update mode, create a consolidated "Recent Changes" section:

```markdown
## Recent Changes (December 2025)

### Core Infrastructure
- WorkerPool now supports dependency injection for testing
- Task submission has typed request overloads

### UI Hooks
- New simulation event hooks: useSectorShock, useSimulationEvent
- Hooks auto-unwrap Serde enum payloads

### Scripts
- Issue data maintenance scripts for pillar normalization
- Agent priors generation from World Bank indicators
- COMTRADE phase 12 fetcher for strategic commodities
```

---

# Key Principles

1. **AGENTS.md only** - Only create/update AGENTS.md files, never CLAUDE.md
2. **Incremental updates** - Append and modify, don't replace entire files
3. **Actual diff preview** - Show real unified diffs, not just summaries
4. **Individual review option** - Let users step through files one by one
5. **Verify subagent writes** - Check git status after subagents complete
6. **Preserve customizations** - Never remove user's manual additions
7. **Parallel execution** - Spawn subagents concurrently for speed
8. **Progress reporting** - Show subagent status during execution
9. **Smart scoping** - Offer depth control for large monorepos
10. **Git-aware** - Use diffs and commit messages for context
11. **Cross-AI compatible** - AGENTS.md works with Claude Code, Codex CLI, and other AI tools

---

# Dry-Run Validation

Before applying subagent outputs, validate the structured format:

**Parse validation:**
```
Validating subagent output for /packages/api/src...
✓ DIRECTORY field present
✓ WARRANTS_AGENTS_MD is boolean
✓ AGENTS_MD_SECTIONS has valid structure
✓ All section names are strings
✓ All content fields are non-empty
```

**Content validation:**
- Section names should be title case
- Content should be valid markdown
- File references should exist in the directory
- No duplicate section names

**On validation failure:**
```
⚠️ Validation failed for /packages/api/src

Issues:
- AGENTS_MD_SECTIONS[2].content is empty
- Section "key files" should be "Key Files" (title case)

[F]ix automatically / [S]kip this file / [A]bort
```

---

# Example Sessions

## Generation (new project)

```
User: generate documentation for this project

Claude: I'll generate AGENTS.md documentation for this project.

Analyzing project structure...
Found 127 source files across 12 directories.

This is a large project. How would you like to scope the documentation?
1. Top-level only - Document root and 4 package directories
2. Full recursive - Analyze all 12 directories
3. Custom - Specify directories

User: 1

Claude: Spawning 4 subagents for top-level packages...

[Subagents complete]

Consolidation complete. Proposed changes:

📁 /AGENTS.md (new)
+# AGENTS.md
+## Overview
+A simulation game with historical modeling...
[preview]

📁 /packages/core/AGENTS.md (new)
+# Core Package
+## Purpose
+Game engine and domain logic...
[preview]

📁 /packages/ui-web/AGENTS.md (new)
+# UI Package
[preview]

Apply these changes? (yes/no/review)

User: yes

Claude: Created 3 AGENTS.md files.
Committed: "Generate AGENTS.md documentation"
```

## Update (existing project)

```
User: update AGENTS.md

Claude: AGENTS.md exists. Analyzing changes...

Last updated: 5 days ago (December 23, 2025)
Commits since: 47
Changed directories: 3

Spawning targeted subagents for:
- /packages/ui-web/src/hooks (8 files changed)
- /packages/core/src/infrastructure (4 files changed)
- /scripts (12 files changed)

[Subagents complete]

Proposed updates:

📁 /packages/ui-web/src/hooks/AGENTS.md
```diff
@@ -38,6 +38,15 @@
 └── useSimulationEvent.ts   # Generic event subscription
+
+## Simulation Event Hooks (December 2025)
+
+### useSectorShock
+Tracks supply chain disruption signals:
+- shock: Current SectorShockWire | null
+- impactByCommodityId: Map<string, number>
```

📁 /packages/core/src/infrastructure/AGENTS.md
```diff
@@ -100,6 +100,20 @@
+### December 2025 - WorkerPool Dependency Injection
+- WorkerPool now supports DI for testing
+- Task submission has typed request overloads
```

Apply these updates? [A]pply all / [R]eview / [S]kip

User: A

Claude: Applied 2 updates.
Committed: "Update AGENTS.md documentation"
```
