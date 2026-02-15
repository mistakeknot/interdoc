# PRD: Structural Auto-Fix for Interdoc

**Bead:** iv-i82

## Problem

AGENTS.md files rot silently between manual `/interdoc` invocations. When files are renamed, deleted, or added, the documentation references become stale. Interwatch detects this drift, and Clavain triggers checks — but nobody actually *fixes* the stale references automatically. The gap is between detection and action.

## Solution

Give Interdoc a structural auto-fix capability: a fast, deterministic shell script that updates AGENTS.md file references (renames, deletions, additions) without LLM tokens. Interdoc stays a fixer/generator — Interwatch stays the detector, Clavain stays the trigger.

## Module Boundary

```
Interwatch (detects) ──drift signals──> Interdoc (fixes) <──triggers── Clavain (orchestrates)
```

- **Interdoc owns:** structural fixes, fix-mode entry point
- **Interwatch owns:** drift scoring, signal detection, confidence tiers, watchables config
- **Clavain owns:** Stop hook triggering, quality-gates integration

## MVP Scope (This Iteration)

**F1 + F5 only.** Markers (F2), convergence loop (F3), and pending-fix accumulation (F4) are deferred to a future iteration after validating that structural drift is a frequent enough pain point.

**Rationale (from flux-drive review):**
- F2-F4 add concurrency complexity (race conditions in shared state) without validated demand
- The core value is "fast deterministic fixes for file structure changes"
- Markers and convergence are semantic concerns better validated after the structural fix is proven

## Features

### F1: Structural Auto-Fix Script (`drift-fix.sh`)
**What:** Shell script that reads git history and deterministically updates AGENTS.md file references.
**Acceptance criteria:**
- [ ] Uses `git log --diff-filter=R -M --name-status` since last AGENTS.md update to find renames
- [ ] Uses `git log --diff-filter=D --name-only` since last AGENTS.md update to find deletions
- [ ] Uses `git log --diff-filter=A --name-only` since last AGENTS.md update to find additions
- [ ] Cross-references against all AGENTS.md files in the repo (grep for mentioned filenames)
- [ ] Updates renamed file references in-place (old name → new name) using `sed`
- [ ] Removes references to deleted files from Key Files tables (markdown table rows and bullet list items)
- [ ] Logs new files that could be added to AGENTS.md (does NOT auto-add — purpose inference requires LLM)
- [ ] Fixes broken internal links between AGENTS.md files (`../*/AGENTS.md` patterns only)
- [ ] Uses atomic writes (write to temp file, `mv` over original) for all AGENTS.md modifications
- [ ] Outputs a JSON summary: `{"renames": [...], "deletions": [...], "new_files": [...], "links_fixed": [...]}`
- [ ] Runs in <2 seconds on a repo with 50 AGENTS.md files
- [ ] Never modifies non-AGENTS.md files
- [ ] Idempotent: running twice on the same git state produces no additional changes
- [ ] Uses `flock` on `.git/interdoc/fix.lock` to prevent concurrent execution
- [ ] If a table format is unsupported, logs the file path and skips (does not fail)
- [ ] Uses git-native rename detection only (no cross-module state reads from Interwatch)

### F5: Fix-Mode Entry Point
**What:** New invocation mode for Interdoc skill: `interdoc fix` that runs structural fixes without full regeneration.
**Acceptance criteria:**
- [ ] Triggered by `/interdoc fix` or "fix stale references" in natural language
- [ ] Runs `drift-fix.sh` for structural fixes
- [ ] Shows unified diff preview of all changes before applying
- [ ] Applies changes immediately (no pending-fix accumulation — apply-or-discard model)
- [ ] User can commit via standard git workflow after reviewing diffs
- [ ] Reports summary: "N renames updated, M deleted references removed, K new files detected"
- [ ] If no structural drift detected, responds: "All AGENTS.md references are current."
- [ ] Can be called programmatically by Interwatch's refresh dispatch
- [ ] On every full `/interdoc` invocation, detect if changes are purely structural and suggest: "Detected only file renames/deletions. Run `/interdoc fix` for a faster update (no LLM tokens)."

## Deferred Features (Phase 2)

### F2: Unverified/Stale Marker System (deferred)
Inline HTML comment markers that flag uncertain AGENTS.md sections. Requires validated demand for semantic drift tracking and a concurrency-safe marker insertion mechanism.

### F3: Convergence Loop Integration (deferred)
Update mode re-evaluates markers on each run. Depends on F2.

### F4: Pending Fixes Commit Helper (deferred)
Accumulation + batch commit pattern. Requires flock-based locking to prevent race conditions from concurrent hooks. The simpler "apply immediately" model in F5 avoids this complexity entirely.

## Non-goals

- **Drift detection** — Interwatch owns this. Interdoc does not compute drift scores.
- **Signal weighting** — Interwatch owns confidence tiers. Interdoc trusts whatever confidence it receives.
- **Trigger architecture** — Clavain owns when to invoke. Interdoc is called, not self-triggering.
- **Semantic auto-fix** — This iteration handles structural (deterministic) fixes only.
- **Auto-adding new files** — New file detection is reported but not auto-added. Purpose inference requires LLM, which contradicts the "deterministic shell script" goal. New files are logged for the user to add manually or via full `/interdoc` update.
- **`.interdoc.yml` config** — Interwatch already has `watchables.yaml`.
- **Reading Interwatch's internal state** — `drift-fix.sh` uses git-native methods only, no cross-module state coupling.

## Dependencies

- **Git** — repo must be a git repository with history (not shallow)
- **Standard Unix tools** — `sed`, `grep`, `jq`, `flock`
- **Existing Interdoc** — builds on SKILL.md mode detection
- **Interwatch** — optional; for drift-triggered invocation (graceful degradation if not installed)

## Resolved Questions (from flux-drive review)

1. **Table format detection:** Support markdown table rows (`| file | desc |`) and bullet list items (`- file — desc`). Skip other formats with a logged warning. This is sufficient for interdoc-generated AGENTS.md files which use these two formats.

2. **Rename detection scope:** Use git-native methods: `git log --diff-filter=R -M --name-status <last-agents-md-commit>..HEAD`. No dependency on Interwatch's `drift.json` or any cross-module state.

3. **Cross-AGENTS.md links:** Handle `../*/AGENTS.md` relative link patterns. Skip absolute paths and non-AGENTS.md links.

4. **New file handling:** Log new files in the summary but do NOT auto-add them. Purpose inference is not deterministic — defer to full `/interdoc` update or manual addition.

5. **Concurrency:** Use `flock` for exclusive access during fix execution. Apply-or-discard model (no accumulation) eliminates the race condition in pending-fixes.json.

6. **Atomic writes:** All AGENTS.md modifications use temp-file + `mv` pattern (POSIX atomic on same filesystem).
