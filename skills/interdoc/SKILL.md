---
name: interdoc
description: Use when user requests CLAUDE.md updates or when documentation needs review after code changes. Analyzes git commits to suggest documentation updates for architecture, implementation details, dependencies, and conventions.
---

# Interdoc: Automated CLAUDE.md Maintenance

## Purpose

Keep CLAUDE.md documentation current by detecting significant code changes and suggesting relevant documentation updates. Reduces manual maintenance burden while keeping humans in control.

## When to Use This Skill

**Automatic invocation** (primary mode):
- SessionStart hook checks for pending updates when user starts/resumes a session
- Automatically triggers if 3+ commits since last CLAUDE.md update
- Or if significant changes detected (new files, config changes)
- You proactively analyze commits and present suggestions
- User approves/rejects without having to manually invoke

**Manual invocation** (optional):
- User explicitly requests: "update CLAUDE.md", "review documentation", "document recent changes"
- After feature completion or before creating PR
- When user wants to review even if threshold not met

## Core Workflow

### Step 1: Detect Baseline

Find when CLAUDE.md was last updated:

```bash
git log -1 --format=%ct CLAUDE.md
```

If CLAUDE.md doesn't exist, offer to create it (see Edge Cases below).

### Step 2: Analyze Recent Commits

Get all commits since the baseline:

```bash
git log --since="@<timestamp>" --format="%H %s"
```

For each commit, examine:
- Files changed (via `git show --stat <commit>`)
- Nature of changes (via `git diff-tree --name-status <commit>`)
- Commit message for context

### Step 3: Categorize Changes

Apply judgment to group changes into categories:

**Architecture Changes** - Structural significance:
- New directories created
- Major reorganization (multiple files moved)
- Changes to build/config files (tsconfig.json, Cargo.toml, etc.)
- New file types introduced (signals tech stack change)

**Implementation Details** - Important lessons:
- Bug fixes with non-obvious solutions
- Complex changes (>200 lines in single file)
- New error handling patterns
- Performance optimizations
- Workarounds or gotchas

**Dependencies** - External tools:
- package.json, requirements.txt, Cargo.toml, go.mod changes
- .claude-plugin/* modifications
- New tools or libraries added

**Conventions** - Repeated patterns:
- Consistent changes across 3+ files
- New naming patterns
- File organization changes
- Workflow additions

**Skip if**:
- Single file, <50 lines, markdown file (likely docs already)
- Trivial changes (typos, formatting)
- No new files/directories

### Step 4: Generate Suggestions

For each category with significant changes, create a suggestion:

```markdown
## [Category]: [Brief Description]

**Triggered by commits**:
- [hash] [commit message]
- [hash] [commit message]

**Proposed documentation**:

[Context-appropriate text formatted to fit existing CLAUDE.md structure]

**Why this matters**: [Explain significance]
```

**Adaptive Structure**:
- Read existing CLAUDE.md to understand structure
- Match tone, style, and header hierarchy
- Insert suggestions into appropriate existing sections
- If no matching section exists, suggest where to add it

### Step 5: Present for Review

Show user the suggestions:

```
I've analyzed [N] commits since the last CLAUDE.md update ([X] days ago).

Found [N] categories of changes:

1. **Architecture**: [brief summary]
   - [commit 1]
   - [commit 2]

2. **Implementation Details**: [brief summary]
   - [commit 3]

Would you like to:
- Review all suggestions individually
- See full suggestions now
- Skip for now
```

If user wants to review:
- Show each suggestion with full context
- Ask: "Add this to CLAUDE.md? (yes/no/edit)"
- Allow user to edit suggested text before applying

### Step 6: Apply Updates

For approved suggestions:
- Read current CLAUDE.md
- Insert updates in appropriate sections
- Maintain existing structure and formatting
- Write updated CLAUDE.md

### Step 7: Cross-AI Compatibility

After updating CLAUDE.md, ensure AGENTS.md exists for Codex CLI compatibility:

**Check if AGENTS.md exists in the same directory as CLAUDE.md**:
- If missing, create with redirect template
- If exists, leave it alone (user may have customized)

**AGENTS.md template**:
```markdown
# Agent Context

For complete project documentation, read CLAUDE.md in this directory.

This file exists for Codex CLI compatibility. All project guidance, architecture, conventions, and lessons learned are maintained in CLAUDE.md.
```

**For mono-repos**: Create AGENTS.md next to each CLAUDE.md file.

### Step 8: Commit Documentation Update

Create a commit documenting the update:

```bash
git add CLAUDE.md AGENTS.md
git commit -m "Update CLAUDE.md with recent changes

- [Category 1]: [brief description]
- [Category 2]: [brief description]

Documented commits: [hash]...[hash]
"
```

Clear the pending queue: `rm .git/interdoc-pending` (if it exists)

## Edge Cases

### Missing CLAUDE.md

If CLAUDE.md doesn't exist:

```
I detected significant changes but CLAUDE.md doesn't exist.

Let me create one with a basic template:
- Repository Purpose
- Architecture
- Current Status
- Key Conventions

You can customize after I create it.
```

**Template**:
```markdown
# CLAUDE.md

## Repository Purpose

[Brief description of what this project does]

## Architecture

[High-level structure and key components]

## Current Status

[What's implemented, what's in progress]

## Key Conventions

[Naming patterns, file organization, workflows]

## Lessons Learned

[Important implementation details and gotchas]
```

After creating, apply the pending suggestions to the new file.

### Mono-repos

Detect mono-repo structure by checking for:
- Multiple package.json files
- Workspace configuration (pnpm-workspace.yaml, lerna.json, etc.)
- packages/ or apps/ directories

**Behavior**:
```
I detected this is a mono-repo.

Your recent commits affected:
- packages/api/
- packages/shared/

I'll create CLAUDE.md files for each package:
- packages/api/CLAUDE.md
- packages/shared/CLAUDE.md
- ./CLAUDE.md (root - overall architecture)
```

**Update targeting**:
- Suggestions target the CLAUDE.md closest to changed files
- Root CLAUDE.md for architectural changes spanning packages
- Package CLAUDE.md for package-specific implementation details

**AGENTS.md for mono-repos**:
- Create AGENTS.md next to each CLAUDE.md (root + packages)
- All redirect to their respective CLAUDE.md in the same directory

### Merge Commits

For merge commits:
- Analyze the merge commit's combined diff
- Don't separately analyze individual commits being merged
- Flag large merges: "This merge includes [N] files - I'll focus on major patterns"

### Large Refactors (>50 files)

When changes are massive:
- Group by directory/module
- Focus on architectural patterns rather than file-by-file
- Limit to top 3 most significant categories
- Present as: "Large refactor detected - focusing on architectural changes"

### No Significant Changes

If analysis finds no significant changes:
```
I reviewed [N] commits since the last CLAUDE.md update.

No significant changes detected - mostly [typos/formatting/minor updates].

CLAUDE.md appears up-to-date.
```

Clear pending queue if it exists.

## Analyzing Change Significance

When analyzing commits, prioritize changes that are:

**Highly significant**:
- New directories created
- 3+ files changed in related commits
- Config files modified (package.json, tsconfig.json, .claude-plugin/*, Cargo.toml, etc.)
- Files moved/renamed (refactoring)
- New file type introduced (tech stack changes)

**Less significant** (can skip or summarize):
- Single file changed with < 50 lines
- Markdown files (likely already documented)
- Pure formatting or typo fixes

Apply judgment - not every commit needs documentation, but architectural changes and important lessons learned should be captured.

## Output Format

**Summary view**:
```
📝 CLAUDE.md Update Suggestions

Analyzed: [N] commits ([date] to [date])

Categories:
1. 🏗️  Architecture ([N] commits)
   Brief summary of architectural changes

2. 💡 Implementation Details ([N] commits)
   Brief summary of lessons learned

3. 📦 Dependencies ([N] commits)
   Brief summary of dependency changes

4. 📋 Conventions ([N] commits)
   Brief summary of new patterns
```

**Detail view** (for each suggestion):
```
## [Icon] [Category]: [Brief Description]

**Commits**:
- abc123: [message]
- def456: [message]

**Proposed Documentation**:

[Full suggested text, formatted to match CLAUDE.md style]

**Why this matters**:
[2-3 sentences explaining significance]

---
Add to CLAUDE.md? (yes/no/edit)
```

## Key Principles

1. **Human control**: User approves all changes
2. **Non-intrusive**: Don't interrupt rapid iteration
3. **Context-aware**: Match existing CLAUDE.md style
4. **Helpful defaults**: Create files, handle mono-repos automatically
5. **Cross-AI compatible**: Maintain AGENTS.md redirects
6. **Apply judgment**: Not all changes need documentation

## Success Indicators

- User approves 50%+ of suggestions (good signal/noise ratio)
- CLAUDE.md stays current within 1 week of major changes
- Hook doesn't feel annoying
- Both Claude Code and Codex CLI work seamlessly
