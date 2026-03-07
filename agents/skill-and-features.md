# Skill & Features

> Cross-AI documentation for interdoc. Works with Claude Code, Codex CLI, and other AI coding tools.

**Why AGENTS.md?** Claude Code reads both AGENTS.md and CLAUDE.md, but AGENTS.md is the cross-AI standard that also works with Codex CLI and other AI coding tools.

## The Skill

| Skill | Trigger | Use Case |
|-------|---------|----------|
| `interdoc` | Natural language (hooks disabled by default) | Generate/update AGENTS.md documentation |

**Discovery:** In Claude Code, ask "List all available Skills" to see interdoc, or run `/interdoc`.

**Advisory hook (optional):** Run `./hooks/git/install-post-commit.sh` to enable a non-blocking reminder after commits.

**Optional modes:** Use phrases like "change-set update", "doc coverage", or "doc lint" to trigger specialized behaviors.

> **Note:** This is a Claude Code plugin skill, invoked via natural language (e.g., "generate documentation for this project"). It is NOT a slash command.

## Key Features

- **Parallel subagents**: Spawns agents per directory for fast analysis
- **Incremental updates**: Appends new content, preserves existing documentation
- **CLAUDE.md harmonization**: Migrates docs from CLAUDE.md → AGENTS.md
- **Unified diff previews**: Shows actual diffs before applying
- **Dry run + cached apply**: Preview changes and apply last preview without re-analysis
- **Structural auto-fix**: Deterministic rename/deletion/link fixes without LLM tokens (`/interdoc fix`)
- **JSON schema output**: Subagents return structured JSON with sentinel markers
- **Git-aware**: Uses commit messages and diffs for update context
- **Scalability guardrails**: Concurrency limits, batch processing for large repos
- **Claude subagent option**: Specialized subagent for high-quality AGENTS.md content

## Interwatch Integration

interdoc is a generator target for interwatch's drift-detection framework. When interwatch detects that AGENTS.md has drifted (files renamed/deleted/created, commit threshold exceeded), it dispatches to `interdoc:interdoc` for regeneration. interdoc does not compute drift scores — interwatch owns detection, interdoc owns generation. The `scripts/interdoc-generator.sh` marker file signals generator availability to interwatch's discovery system.

## Hooks (Disabled by Default)

Hooks are not enabled by default. Manual invocation is the standard flow.
