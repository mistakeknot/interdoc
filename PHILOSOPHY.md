# interdoc Philosophy

## Purpose
Recursive AGENTS.md generator with integrated GPT 5.2 Pro critique, CLAUDE.md harmonization, incremental updates, diff previews, and smart monorepo scoping. Cross-AI compatible.

## North Star
Optimize for trustworthy documentation generation: structural correctness first, then incremental update quality and critique loops.

## Working Priorities
- Doc correctness
- Incremental updates
- Cross-AI critique loops

## Brainstorming Doctrine
1. Start from outcomes and failure modes, not implementation details.
2. Generate at least three options: conservative, balanced, and aggressive.
3. Explicitly call out assumptions, unknowns, and dependency risk across modules.
4. Prefer ideas that improve clarity, reversibility, and operational visibility.

## Planning Doctrine
1. Convert selected direction into small, testable, reversible slices.
2. Define acceptance criteria, verification steps, and rollback path for each slice.
3. Sequence dependencies explicitly and keep integration contracts narrow.
4. Reserve optimization work until correctness and reliability are proven.

## Decision Filters
- Does this reduce ambiguity for future sessions?
- Does this improve reliability without inflating cognitive load?
- Is the change observable, measurable, and easy to verify?
- Can we revert safely if assumptions fail?

## Evidence Base
- Brainstorms analyzed: 1
- Plans analyzed: 6
- Source confidence: artifact-backed (1 brainstorm(s), 6 plan(s))
- Representative artifacts:
  - `docs/brainstorms/2026-02-13-self-healing-docs-brainstorm.md`
  - `docs/plans/2025-12-28-subagent-refactor-design.md`
  - `docs/plans/2026-01-18-interdoc-discovery.md`
  - `docs/plans/2026-01-18-interdoc-dry-run.md`
  - `docs/plans/2026-01-18-interdoc-git-hook.md`
  - `docs/plans/2026-01-18-interdoc-roadmap.md`
  - `docs/plans/2026-02-14-structural-autofix.md`
