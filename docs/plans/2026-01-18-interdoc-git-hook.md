# Interdoc Advisory Git Hook Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Bead:** N/A (beads not initialized in this repo)

**Goal:** Add an opt-in post-commit hook that advises when AGENTS.md may be stale, without blocking commits.

**Architecture:** Provide a Git hook script under `hooks/git/post-commit`, plus an installer script that symlinks or copies it into `.git/hooks/post-commit`. Update README and AGENTS.md with opt-in instructions.

**Tech Stack:** Shell scripts in `hooks/git/`, README/AGENTS documentation.

---

### Task 1: Add advisory post-commit hook

**Files:**
- Create: `hooks/git/post-commit`

**Step 1: Implement hook logic**
- Detect repo root with `git rev-parse --show-toplevel`.
- Exit if not in git repo.
- If no `AGENTS.md`, print advisory message.
- If `AGENTS.md` exists, find last commit touching it and count commits since.
- If commits since >= threshold (e.g., 10), print advisory message.
- Never exit non-zero; do not block commit.

**Step 2: Make script executable**

---

### Task 2: Add installer script

**Files:**
- Create: `hooks/git/install-post-commit.sh`

**Step 1: Create install script**
- Symlink or copy `hooks/git/post-commit` into `.git/hooks/post-commit`.
- Preserve existing hook by backing it up if present.

**Step 2: Make script executable**

---

### Task 3: Document opt-in usage

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

**Step 1: Add a short section**
- Explain advisory nature and install command.
- Mention it won’t block commits.

---

### Task 4: Consistency check

**Files:**
- Modify: `README.md`, `AGENTS.md`

**Step 1: Ensure wording matches advisory behavior**

---

### Task 5: Document testing status

**Files:**
- None

**Step 1: Note that no tests were run**
- Documentation-only change.
