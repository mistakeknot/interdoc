# AGENTS.md — interdoc

Recursive AGENTS.md generator with integrated GPT 5.2 Pro critique. Analyzes project structure via parallel subagents, consolidates into coherent documentation, and optionally sends to GPT for independent review.

**Plugin Type:** Claude Code skill plugin
**Plugin Namespace:** `interdoc` (from interagency-marketplace)
**Current Version:** 5.0.0

## Canonical References
1. [`PHILOSOPHY.md`](../../PHILOSOPHY.md) — direction for ideation and planning decisions.
2. `CLAUDE.md` — implementation details, architecture, testing, and release workflow.

## Quick Reference

| Trigger | Mode | Scope |
|---------|------|-------|
| "generate AGENTS.md" | Generation | Full project |
| "update AGENTS.md" | Update | Changed directories |
| "change-set update" | Update | Git diff only |
| "doc coverage" | Report | Coverage stats |
| "lint AGENTS.md" / "doc lint" | Lint | Style warnings |
| "fix stale references" / "interdoc fix" | Fix | Structural only (no LLM) |
| "dry run" | Any + Preview | No writes |

## Topic Guides

| Topic | File | Covers |
|-------|------|--------|
| Skill & Features | [agents/skill-and-features.md](agents/skill-and-features.md) | Skill triggers, key features, interwatch integration, hooks |
| Development & Versioning | [agents/development.md](agents/development.md) | Editing behavior, testing, version bumps, marketplace publish, commit workflow |
| GPT Review | [agents/gpt-review.md](agents/gpt-review.md) | Oracle integration, review classification, helper scripts, troubleshooting |
| Changelog | [agents/changelog.md](agents/changelog.md) | Version history (v4.1.0 through v4.4.3) |

## Repository Structure

```
/
├── .claude/
│   └── agents/
│       └── interdocumentarian.md  # Claude subagent for AGENTS.md authoring
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata and version (source of truth)
├── .codex/
│   └── INSTALL.md            # Codex CLI install instructions
├── hooks/
│   ├── check-updates.sh     # Hook script (disabled by default)
│   └── check-commit.sh      # Hook script (disabled by default)
│   ├── git/
│   │   ├── post-commit       # Advisory commit hook
│   │   └── install-post-commit.sh
│   └── tools/
│       └── interdoc-audit.sh  # Coverage + lint helper
├── scripts/
│   ├── drift-fix.sh       # Structural auto-fix (renames, deletions, link fixes)
│   ├── bump-version.sh    # Version management
│   ├── check-versions.sh  # Version consistency checker
│   └── interdoc-generator.sh
├── skills/
│   └── interdoc/
│       └── SKILL.md         # Main skill definition
├── docs/
│   ├── plans/               # Design documents
│   └── TEST_PLAN.md         # Test cases from splinterpeer analysis
├── tests/
│   ├── fixtures/
│   │   └── setup-test-repo.sh  # Test repo scaffolding
│   ├── test-drift-fix-*.sh     # drift-fix.sh test suite
│   └── run-all.sh              # Test runner
├── README.md                # User-facing documentation
├── CLAUDE.md                # Claude-specific settings only
└── AGENTS.md                # This file - cross-AI documentation
```

## Philosophy Alignment Protocol

**Operational implementation:** The interdoc skill loads PHILOSOPHY.md, MISSION.md, and `.interlore/proposals.yaml` (if present) in Step 0b of the generation workflow. This context informs how the project overview, architecture, and conventions sections are framed.

Review [`PHILOSOPHY.md`](../../PHILOSOPHY.md) during:
- Intake/scoping
- Brainstorming
- Planning
- Execution kickoff
- Review/gates
- Handoff/retrospective

For brainstorming/planning outputs, add two short lines:
- **Alignment:** one sentence on how the proposal supports the module's purpose within Demarch's philosophy.
- **Conflict/Risk:** one sentence on any tension with philosophy (or 'none').

If a high-value change conflicts with philosophy, either:
- adjust the plan to align, or
- create follow-up work to update `PHILOSOPHY.md` explicitly.
