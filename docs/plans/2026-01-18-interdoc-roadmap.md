# Interdoc Roadmap Phase 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Bead:** N/A (beads not initialized in this repo)

**Goal:** Implement Phase 1 roadmap items: change-set driven updates, doc coverage report, and lightweight style lint.

**Architecture:** Add new workflow rules and optional scripts/docs in Interdoc to support selective directory analysis, coverage reporting, and lint warnings. Keep implementation documentation-driven with clear steps and opt-in flags.

**Tech Stack:** Markdown docs (`skills/interdoc/SKILL.md`, `README.md`, `AGENTS.md`), optional helper script in `hooks/tools/`.

---

### Task 1: Change-set driven updates (docs + workflow)

**Files:**
- Modify: `skills/interdoc/SKILL.md`
- Modify: `README.md`

**Step 1: Add “Change-Set Update Mode” section**
- Define behavior: use `git diff --name-only` to select directories for analysis.
- If no changes detected, short-circuit with “No updates required.”

**Step 2: Provide example command**
- `git diff --name-only HEAD~1..HEAD` or user-defined base.

**Step 3: Document opt-in phrase**
- “update AGENTS.md for changed files only” or “change-set update.”

---

### Task 2: Doc coverage report

**Files:**
- Modify: `skills/interdoc/SKILL.md`
- Modify: `README.md`

**Step 1: Define coverage report output**
- % coverage, list of undocumented directories.
- Document how directories are counted (e.g., source dirs with 5+ files or package manifests).

**Step 2: Add optional mode trigger**
- “coverage report” or “doc coverage.”

---

### Task 3: Lightweight style lint

**Files:**
- Modify: `skills/interdoc/SKILL.md`
- Modify: `README.md`

**Step 1: Define lint checks**
- Missing required sections, empty Gotchas, paragraphs > N lines.
- Output as warnings; never block generation.

**Step 2: Add trigger phrase**
- “lint AGENTS.md” or “doc lint.”

---

### Task 4: Optional helper script (coverage + lint)

**Files:**
- Create: `hooks/tools/interdoc-audit.sh`
- Modify: `README.md`

**Step 1: Add script**
- Read AGENTS.md and emit coverage + lint warnings.
- Keep non-blocking and advisory.

**Step 2: Document usage**
- `./hooks/tools/interdoc-audit.sh` for quick local checks.

---

### Task 5: Consistency check

**Files:**
- Modify: `skills/interdoc/SKILL.md`, `README.md`, `AGENTS.md`

**Step 1: Ensure triggers and output names match**

---

### Task 6: Document testing status

**Files:**
- None

**Step 1: Note that no tests were run**
- Documentation-only change.
