# CLAUDE.md Harmonization Reference

This reference contains the detailed workflow for harmonizing CLAUDE.md with AGENTS.md.

## The Problem

Many projects have duplicate documentation in both CLAUDE.md and AGENTS.md:
- Architecture described twice
- Conventions repeated
- Commands in both files
- Only Claude Code reads CLAUDE.md; other AI tools ignore it

## Heading Classification

### Keep in CLAUDE.md (Allowlist)

These headings (case-insensitive) stay in CLAUDE.md:

| Pattern | Examples |
|---------|----------|
| `Claude*` | `Claude Settings`, `Claude-Specific`, `Claude Code Hooks` |
| `Model Preference*` | `Model Preferences`, `Model Selection` |
| `Tool Setting*` | `Tool Settings`, `Tool Restrictions` |
| `Approval*` | `Approval Settings`, `Auto-Approve Rules` |
| `Safety*` | `Safety Settings`, `Safety Rules` |
| `Hook*` | `Hooks`, `Hook Configuration` |
| `Permission*` | `Permissions`, `Permission Rules` |
| `Workaround*` | `Workarounds`, `Claude Workarounds` |

### Migrate to AGENTS.md (Everything Else)

All other headings move to AGENTS.md:

| Heading | Target Section in AGENTS.md |
|---------|---------------------------|
| `Overview`, `Introduction` | Overview |
| `Architecture`, `Structure` | Architecture |
| `Conventions`, `Style` | Conventions |
| `Commands`, `Scripts` | Development / Commands |
| `Directory Structure`, `Layout` | Architecture |
| `Gotchas`, `Known Issues`, `Caveats` | Gotchas |
| `Dependencies` | Dependencies |
| `Testing` | Development |
| `Deployment` | Development |

## User-Controlled Markers

### Keep Marker

```markdown
<!-- interdoc:keep -->
This content stays in CLAUDE.md regardless of heading.
It might be Claude-specific context that doesn't fit standard headings.
<!-- /interdoc:keep -->
```

### Move Marker

```markdown
<!-- interdoc:move -->
This content moves to AGENTS.md regardless of heading.
Useful for documentation accidentally placed in CLAUDE.md.
<!-- /interdoc:move -->
```

## Migration Algorithm

```
1. Read CLAUDE.md
2. Parse into sections by heading
3. For each section:
   a. Check for interdoc markers
   b. If no markers, classify by heading pattern
   c. Mark as KEEP or MIGRATE
4. Build new CLAUDE.md from KEEP sections
5. Merge MIGRATE sections into AGENTS.md
6. Show diff preview
7. Apply on approval
```

## Slim CLAUDE.md Template

```markdown
# CLAUDE.md

> **Documentation is in AGENTS.md** - This file contains Claude-specific settings only.
> For project documentation, architecture, and conventions, see [AGENTS.md](./AGENTS.md).

## Claude-Specific Settings

[Extracted Claude-specific content]

## See Also

- [AGENTS.md](./AGENTS.md) - Full project documentation
```

## Content Merging Rules

When migrating content to AGENTS.md:

| AGENTS.md State | Action |
|-----------------|--------|
| Section doesn't exist | Create new section |
| Section exists, content identical | Skip (already documented) |
| Section exists, content different | Merge, keep more detailed version |
| Section exists, content conflicting | Keep both with note |

### Conflict Resolution

```markdown
## Architecture

[Existing content from AGENTS.md]

### Additional Notes (from CLAUDE.md)

[Content migrated from CLAUDE.md that differs from above]
```

## Fallback Handling

### Unstructured CLAUDE.md

If CLAUDE.md doesn't use standard headings:

```
⚠️ CLAUDE.md at {path} doesn't use standard headings.
Cannot automatically classify content.

Options:
[V] View file and manually mark sections
[S] Skip this file
[K] Keep entire file as-is
```

### Very Large CLAUDE.md

If CLAUDE.md is >500 lines:

```
⚠️ CLAUDE.md at {path} is very large (743 lines).
Review recommended before automatic harmonization.

Options:
[R] Review content classification before applying
[S] Skip this file
[A] Apply automatic classification (may need manual review)
```

## Non-Destructive Preservation

Before modifying CLAUDE.md:

1. Create backup: `CLAUDE.md.bak` (git-ignored)
2. Or append archive section:

```markdown
---

## Archived Content (moved to AGENTS.md)

The following was moved to AGENTS.md on YYYY-MM-DD:
- Project Overview
- Architecture
- Conventions
- Commands

To restore, see `AGENTS.md` or `.git/interdoc/claude-md-backup-{timestamp}.md`
```
