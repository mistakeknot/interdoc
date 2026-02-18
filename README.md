# interdoc

Recursive AGENTS.md generator for Claude Code.

## What This Does

Point interdoc at a project and it produces cross-AI compatible documentation — AGENTS.md files that work with Claude Code, Codex CLI, and whatever comes next. It spawns parallel subagents to analyze each directory, consolidates their findings, deduplicates cross-cutting patterns, and shows you a unified diff before writing anything.

**Why AGENTS.md?** Claude Code reads both AGENTS.md and CLAUDE.md, but AGENTS.md is the cross-AI standard. Using it as the primary format means your documentation works regardless of which agent you're running.

The skill auto-detects mode: no AGENTS.md means generation (full recursive pass), existing AGENTS.md means update (incremental changes only, preserving what you've already written).

## Installation

```bash
/plugin install interdoc
```

Or manually:

```bash
git clone https://github.com/mistakeknot/interdoc.git
cd interdoc && /plugin install .
```

## Usage

Ask naturally — interdoc picks up the intent:

```
"generate documentation for this project"
"update AGENTS.md"
"fix stale references"
```

### Key Modes

**Generation** — spawns one subagent per directory in parallel, each analyzing purpose/architecture/conventions/gotchas, then consolidates into coherent docs with cross-references. For large projects (100+ files), it offers scoping: top-level only, full recursive, or custom.

**Update** — detects git changes since last update, skips up-to-date directories, and proposes incremental additions/modifications/deletions rather than full rewrites. Shows exact diffs in unified diff format.

**Fix** — deterministic structural repairs (broken cross-links from renames, deletions, moves) without spending LLM tokens. Use `/interdoc fix` after reorganizing files.

**CLAUDE.md harmonization** — if you have both CLAUDE.md and AGENTS.md, interdoc can consolidate them: migrates project docs to AGENTS.md, slims CLAUDE.md to settings only, adds a pointer.

### GPT-Powered Review

After generating docs, interdoc automatically sends them to GPT 5.2 Pro for independent critique via [Oracle](https://github.com/steipete/oracle). This catches blind spots that self-review misses. Never blocks if Oracle is unavailable — the feature is additive, not required.

### Dry Run

Add "dry run" to your request to preview without writing. Apply later with "apply last preview" (valid until HEAD changes).

## Architecture

```
skills/interdoc/SKILL.md     Main skill definition
hooks/                       SessionStart (check freshness), PostToolUse (commit check)
.claude/agents/              interdocumentarian.md (specialized directory analyzer)
```

## Credits

MK (mistakeknot@vibeguider.org)

## License

MIT
