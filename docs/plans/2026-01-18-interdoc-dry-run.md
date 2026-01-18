# Interdoc Dry-Run Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Bead:** N/A (beads not initialized in this repo)

**Goal:** Document a dry-run mode that previews diffs, summarizes changes, and supports a cached “apply last preview” path without re-analysis.

**Architecture:** Update `skills/interdoc/SKILL.md` to define dry-run triggers, preview summary format, default auto-apply behavior, and cached apply workflow with HEAD-based invalidation. Add a short README note.

**Tech Stack:** Markdown docs in `skills/interdoc/SKILL.md`, `README.md`.

---

### Task 1: Add dry-run triggers and default auto-apply behavior

**Files:**
- Modify: `skills/interdoc/SKILL.md`

**Step 1: Add a “Dry Run Mode” subsection**
- Define trigger phrases: “dry run”, “preview only”, “no write”, “show changes only”.
- State: if no dry-run keyword is present, apply without confirmation.

**Step 2: Add a “Default Apply” note**
- Explicitly remove the “Apply these changes?” prompt for non-dry-run runs.

**Step 3: Save file**

---

### Task 2: Add summary block before diff preview

**Files:**
- Modify: `skills/interdoc/SKILL.md`

**Step 1: Define the summary format**
- Counts: new/updated/deleted AGENTS.md files.
- Per-directory list with action (new/update/delete).

**Step 2: Place summary before unified diff preview**
- Ensure it appears in both dry-run and normal runs.

**Step 3: Save file**

---

### Task 3: Add cached “apply last preview” flow

**Files:**
- Modify: `skills/interdoc/SKILL.md`

**Step 1: Define cache storage**
- Use `.git/interdoc/preview.json` and `.git/interdoc/preview.patch`.
- Include HEAD hash and timestamp in the cache metadata.

**Step 2: Define “apply last preview” behavior**
- If HEAD differs or repo is dirty, refuse and require fresh dry-run.
- If valid, apply patch and report changes.

**Step 3: Add user-facing text**
- At end of dry-run: “Dry run complete — no files were written. To apply without re-analysis, say ‘apply last preview’ (valid until HEAD changes).”

**Step 4: Save file**

---

### Task 4: Add README note

**Files:**
- Modify: `README.md`

**Step 1: Add a short “Dry Run” note**
- Mention trigger phrases and “apply last preview”.

**Step 2: Save file**

---

### Task 5: Consistency check

**Files:**
- Modify: `skills/interdoc/SKILL.md`

**Step 1: Ensure dry-run instructions appear in both Generation and Update modes**
- Confirm language is explicit and consistent.

**Step 2: Save file**

---

### Task 6: Document testing status

**Files:**
- None

**Step 1: Note that no tests were run**
- Documentation-only change.
