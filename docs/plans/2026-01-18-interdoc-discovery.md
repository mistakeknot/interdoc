# Interdoc Discovery Improvements Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Bead:** N/A (beads not initialized in this repo)

**Goal:** Improve Interdoc discovery and invocation in Claude Code via clearer skill description, a slash command, and README/AGENTS notes.

**Architecture:** Update SKILL.md frontmatter description, add a plugin command file, and add brief discovery guidance in docs. Keep scope minimal and documentation-driven.

**Tech Stack:** Markdown docs in `skills/interdoc/SKILL.md`, `README.md`, `AGENTS.md`, and new `commands/interdoc.md` with manifest update in `.claude-plugin/plugin.json`.

---

### Task 1: Update skill description for auto-invocation

**Files:**
- Modify: `skills/interdoc/SKILL.md`

**Step 1: Update frontmatter description**
- Include explicit trigger phrases such as “generate AGENTS.md”, “update AGENTS.md”, “document this repo”.

**Step 2: Save file**

---

### Task 2: Add a slash command

**Files:**
- Create: `commands/interdoc.md`
- Modify: `.claude-plugin/plugin.json`

**Step 1: Create commands file**
- Provide a short description and usage prompt that triggers the interdoc skill.

**Step 2: Register commands in plugin manifest**
- Add `commands` array to `.claude-plugin/plugin.json` if missing.
- Include `./commands/interdoc.md`.

**Step 3: Save files**

---

### Task 3: Add discovery guidance to docs

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

**Step 1: Add a brief discovery note**
- Mention "List all available Skills" in Claude Code.
- Provide 2-3 example prompts that invoke interdoc.

**Step 2: Save files**

---

### Task 4: Consistency check

**Files:**
- Modify: `skills/interdoc/SKILL.md`, `README.md`, `AGENTS.md`

**Step 1: Ensure language matches updated triggers**
- Same wording across docs.

---

### Task 5: Document testing status

**Files:**
- None

**Step 1: Note that no tests were run**
- Documentation-only change.
