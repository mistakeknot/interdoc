# interdoc — Vision and Philosophy

**Version:** 0.1.0
**Last updated:** 2026-02-28

## What interdoc Is

interdoc is a recursive AGENTS.md generator for Claude Code. It walks a project tree, spawns parallel subagents to analyze each directory, consolidates their findings into coherent cross-AI documentation, and then sends the result to GPT 5.2 Pro for independent critique via Oracle. The generation step (Claude) and the review step (GPT) are structurally separated: one model cannot review its own output. Non-controversial suggestions from GPT are applied silently; significant ones prompt the user.

The plugin exists at the intersection of two conventions that currently have no tooling: AGENTS.md as the emerging cross-AI documentation standard, and cross-model review as a forcing function for documentation quality. interdoc is what happens when both are taken seriously at once.

## Why This Exists

Documentation is agent memory. AGENTS.md files are not commentary — they are the persistent state that lets a new session pick up where the last one left off without re-deriving context. Bad docs mean wasted tokens and repeated mistakes. Good docs compound. Every improvement to documentation improves every future session that reads it. interdoc exists because generating and maintaining that documentation by hand does not scale, and self-review (one model checking its own output) produces systematically overconfident results.

## Design Principles

1. **Cross-model review is structural, not optional.** Claude generates; GPT critiques. The separation is architectural. Different models have different blind spots, and disagreement between them is the signal with the highest information density. interdoc does not let generation and review collapse into the same model.

2. **Documentation is a first-class artifact.** AGENTS.md files are not afterthoughts appended to "real" work. They are the interface between sessions, the configuration surface for agent behavior, and the evidence base for future decisions. interdoc treats them with the same rigor as code.

3. **Incremental over rewrite.** Update mode detects what changed since the last run, touches only what changed, and preserves what the author has already written. Wholesale rewrites destroy institutional context. Surgical updates preserve it.

4. **Never block on review unavailability.** Oracle requires an active ChatGPT session and X11 infrastructure. If Oracle is unavailable, generation proceeds and the review phase is skipped cleanly. The tool is additive, not load-bearing on external dependencies.

5. **Demarch documents itself with interdoc.** This is both a design constraint and a trust-earning mechanism. If interdoc cannot maintain its own AGENTS.md and the Demarch monorepo's documentation, the tool is not good enough. Self-application surfaces friction that user reports would not.

## Scope

**What interdoc does:**
- Generates AGENTS.md files recursively across a project tree using parallel subagents
- Detects and applies incremental updates when documentation already exists
- Harmonizes CLAUDE.md and AGENTS.md (migrates project docs to AGENTS.md, slims CLAUDE.md to settings only)
- Sends generated docs to GPT 5.2 Pro for independent critique via Oracle; classifies and applies or surfaces suggestions
- Repairs structural drift (broken cross-links, stale references after renames) without spending LLM tokens

**What interdoc does not do:**
- Generate documentation for non-Claude-Code agent systems (AGENTS.md is the output format, but the plugin runs inside Claude Code)
- Replace human judgment on significant documentation decisions — it prompts, not decides
- Operate autonomously on a schedule — invocation is manual or hook-advisory, never automatic

## Direction

- Add coverage reporting so projects can see which directories lack documentation and quantify documentation debt as a trackable metric
- Extend the critique loop to catch not just style and accuracy issues but also missing architecture decisions, undocumented failure modes, and gaps in the onboarding path
- Deepen self-application: run interdoc on the Demarch monorepo on a regular cadence so the tool's own development is continuously stress-tested against the use cases it is meant to solve
