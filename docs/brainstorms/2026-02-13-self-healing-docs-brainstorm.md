# Self-Healing Documentation System

**Date:** 2026-02-13
**Status:** Brainstorm complete, ready for planning

## What We're Building

A fully autonomous documentation maintenance system for interdoc. Once AGENTS.md files exist, they stay correct without human intervention. The system detects drift continuously, fixes what it can confidently, flags what it can't, and converges toward accuracy over time.

**Core principle:** Users never have to update docs or agent files again.

## Why This Approach

The current interdoc is **reactive** — someone must remember to run `/interdoc`. Documentation rots silently between invocations. The self-healing model inverts this: drift detection runs continuously, fixes are applied automatically based on confidence, and the GPT review phase (via Oracle/auracoil) provides a second-model verification loop that dramatically increases fix confidence.

Three alternatives were considered:
1. **Monitor + nudge** — detect drift, tell the user. Rejected: still requires human action, docs stay stale until someone acts.
2. **Pre-push quality gate** — block pushes until docs are current. Rejected: adds friction, doesn't fix anything autonomously.
3. **Self-healing with confidence tiers** — fix automatically, mark uncertainty. **Selected:** maximum autonomy, clear contract on what's verified vs flagged.

## Key Decisions

1. **Confidence-based autonomy, not approval-based.** interdoc doesn't ask permission — it acts based on how confident it is. Certain fixes are silent. Uncertain fixes get `<!-- interdoc:unverified -->` markers.

2. **Pre-push as informational summary, not a gate.** Never blocks pushes. Shows drift status as a one-liner so the developer knows, but doesn't interrupt flow.

3. **Oracle review requires human approval by default.** Oracle/GPT runs are lengthy and costly. The default is to prompt before running. Users can set `oracle_auto_approve: true` in `.interdoc.yml` for full autopilot.

4. **Two-model verification loop.** Claude generates fixes, GPT reviews them. Combined agreement = high confidence auto-apply. Disagreement = `<!-- interdoc:unverified -->` marker. This dramatically expands what can be auto-fixed.

5. **Configuration lives in `.interdoc.yml` in repo root.** Per-repo, version-controlled, portable.

6. **Structural detection is always free.** Git commands only, no LLM tokens. Tokens are spent only for semantic analysis on flagged directories.

---

## Architecture

### Drift Detection Engine

Every AGENTS.md-documented directory gets a **drift score** computed from weighted signals:

| Signal | Weight | Detection Method | Cost |
|--------|--------|-----------------|------|
| File deleted but referenced in AGENTS.md | High (3) | `git diff --name-status` | Free |
| File renamed but old name in AGENTS.md | High (3) | `git diff --name-status -M` | Free |
| New files in documented dir, not mentioned | Medium (2) | `git diff --name-only` vs AGENTS.md | Free |
| New directory with 5+ files, no AGENTS.md | Medium (2) | `find` + check | Free |
| Commit count since last AGENTS.md update | Medium (1-2) | `git rev-list --count` | Free |
| Days since last AGENTS.md update | Low (1) | `git log -1 --format=%ct` | Free |
| Export/API surface differs from docs | High (3) | Read signatures + compare | Tokens |
| Architecture pattern changed | High (3) | Subagent analysis | Tokens |

**Score → confidence tier mapping:**
- Score 0-2: Green (docs are current)
- Score 3-5: Yellow (drift detected)
- Score 6+: Red (significant drift)

### Confidence Tiers

Confidence determines what interdoc does **without asking**:

| Confidence | Action | Examples |
|---|---|---|
| **Certain** | Fix silently, commit | File renamed, file deleted, new file added to existing table, command changed in package.json |
| **High** | Fix + brief commit note | Function renamed, export changed, dependency added/removed. With GPT review: new file descriptions, section updates |
| **Medium** | Fix + `<!-- interdoc:unverified -->` marker | Architecture description seems outdated, convention may have changed. With GPT review: most content updates |
| **Low** | Don't fix content, add `<!-- interdoc:stale -->` marker only | Subjective claims, prose descriptions of intent, Claude and GPT disagree |

### The Unverified Marker

```markdown
## Architecture

<!-- interdoc:unverified since=2026-02-10 reason="DI pattern detected but docs describe singleton" -->
Uses a singleton pattern for database connections.
<!-- /interdoc:unverified -->
```

Properties:
- Visible to humans reading the markdown
- Machine-readable for future interdoc runs (knows what to re-check)
- Includes reason and date for context
- Automatically removed when interdoc later verifies content is correct or replaces it
- Converges: each subsequent run re-evaluates with more evidence

### The Stale Marker

```markdown
<!-- interdoc:stale since=2026-02-10 commits-behind=34 -->
```

Lighter weight — just signals "this section hasn't been verified in a while" without flagging specific content. Added when commit count or days exceed thresholds.

---

## Trigger Architecture

### Layer 1: Post-Commit Hook (always, <1 second, free)

Runs after every commit. Shell script only, no LLM.

1. `git diff --name-status -M HEAD~1..HEAD` — renames, deletions, additions
2. Cross-reference against all AGENTS.md files (grep for mentioned filenames)
3. Compute structural drift score per directory
4. **Certain fixes applied immediately:**
   - Update renamed file references in AGENTS.md
   - Remove references to deleted files
   - Add new files to Key Files tables (using filename + extension to infer purpose)
   - Fix broken internal links between AGENTS.md files
5. Stage fixes into a doc-fixup commit:
   ```
   docs(interdoc): auto-update stale references

   - Renamed auth.ts -> authenticate.ts in src/api/AGENTS.md
   - Added new-endpoint.ts to Key Files in src/api/AGENTS.md
   - Removed deleted utils/legacy.ts reference
   ```
6. Update `.git/interdoc/drift.json` with current scores

### Layer 2: Session-Start Hook (async, background, may cost tokens)

Runs when Claude Code starts. Async so it doesn't block the user.

1. Load accumulated drift from `.git/interdoc/drift.json`
2. For directories with Yellow/Red drift scores, run semantic analysis:
   - Read changed files' exports/signatures (not full bodies)
   - Compare against AGENTS.md claims
   - Generate fixes for High-confidence items
   - Add `<!-- interdoc:unverified -->` markers for Medium-confidence items
   - Add `<!-- interdoc:stale -->` markers for Low-confidence items
3. For new directories with 5+ files and no AGENTS.md, auto-generate one using subagent
4. Show brief summary to user:
   ```
   interdoc: 12 docs current, 2 auto-fixed, 1 has unverified sections
   ```

### Layer 3: Pre-Push (informational, non-blocking)

Runs before push. Never blocks.

1. Count unverified/stale markers across all AGENTS.md files
2. Show one-line summary:
   ```
   interdoc: 14 docs current, 2 unverified sections, 0 stale
   ```
3. If Oracle review hasn't run recently and there are unverified markers, suggest:
   ```
   interdoc: 2 unverified sections could be resolved with GPT review. Run /interdoc review? (y/n)
   ```

### Layer 4: Scheduled/CI (deep, token cost, Oracle cost)

Designed for cron or CI. Full re-analysis:

1. Re-analyze all documented directories with subagents
2. Re-evaluate all `<!-- interdoc:unverified -->` markers
3. Re-evaluate all `<!-- interdoc:stale -->` markers
4. Send proposed changes through GPT review (Oracle)
5. Apply GPT-verified fixes (High confidence after two-model agreement)
6. Generate AGENTS.md for any undocumented directories meeting threshold
7. Produce drift report (markdown or GitHub issue)
8. Remove resolved markers, update remaining ones

---

## Two-Model Verification Loop (Oracle/GPT Integration)

The existing review phase (auracoil, now folded into interdoc) provides the second model.

### How It Integrates with Self-Healing

```
drift detected
     |
     v
Claude generates proposed fix
     |
     v
Is fix Certain? (deterministic, structural)
     |-- YES --> apply silently (no Oracle needed)
     |-- NO  --> Is Oracle available AND approved?
                    |-- YES --> send fix + context to GPT for review
                    |               |
                    |               v
                    |          GPT agrees?
                    |               |-- YES --> confidence = High, auto-apply
                    |               |-- PARTIAL --> apply agreed parts, mark rest unverified
                    |               |-- NO --> mark as unverified (Claude and GPT disagree)
                    |
                    |-- NO (Oracle unavailable or not approved)
                              --> use Claude-only confidence (more conservative)
                              --> Medium fixes get unverified markers
                              --> Low fixes get stale markers
```

### Oracle Approval Gate

**Default behavior:** Before any Oracle run, prompt the user:

```
interdoc wants to run GPT review on 3 proposed doc updates.
Estimated time: 2-5 minutes. Proceed? (y/n)
```

**Config override in `.interdoc.yml`:**

```yaml
oracle:
  auto_approve: false    # default: require human approval
  # Set to true for full autopilot (Oracle runs without asking)
```

When `auto_approve: true`, Oracle runs are triggered automatically during session-start and scheduled runs. The user opted into the cost.

### Degraded Mode (No Oracle)

The system works without Oracle — it's just more conservative:

| With Oracle | Without Oracle |
|---|---|
| New file descriptions → High (auto-apply) | → Medium (apply + unverified marker) |
| Architecture updates → Medium-High (auto-apply) | → Low (stale marker only) |
| Convention changes → Medium (auto-apply with marker) | → Low (stale marker only) |
| Full re-analysis → High confidence, most auto-applied | → Medium, more markers |

Oracle doesn't gate the system — it amplifies confidence. interdoc is still fully functional without it.

---

## Persistent State

### `.git/interdoc/` Directory

```
.git/interdoc/
├── drift.json          # Current drift scores per directory
├── pending-fixes.json  # Accumulated fixes between sessions
├── history.json        # When each AGENTS.md was last verified
├── last-review.json    # Last Oracle review metadata
├── config-cache.json   # Parsed .interdoc.yml
└── preview.patch       # Existing: dry-run preview cache
```

### `drift.json` Schema

```json
{
  "schema": "interdoc.drift.v1",
  "scanned_at": "2026-02-10T14:30:00Z",
  "head": "abc123",
  "directories": {
    "src/api": {
      "score": 4,
      "signals": [
        {"type": "file_renamed", "old": "auth.ts", "new": "authenticate.ts", "weight": 3},
        {"type": "commits_since_update", "count": 12, "weight": 1}
      ],
      "agents_md_last_updated": "2026-01-15",
      "agents_md_last_verified": "2026-02-08"
    }
  }
}
```

Key distinction: **last_updated** (git modification time) vs **last_verified** (when interdoc confirmed accuracy). A file updated 3 months ago but verified yesterday is green.

### `history.json` Schema

```json
{
  "schema": "interdoc.history.v1",
  "entries": [
    {
      "directory": "src/api",
      "action": "auto_fix",
      "confidence": "certain",
      "changes": ["renamed auth.ts -> authenticate.ts"],
      "timestamp": "2026-02-10T14:30:00Z",
      "commit": "def456"
    },
    {
      "directory": "lib/auth",
      "action": "generated",
      "confidence": "high",
      "oracle_verified": true,
      "timestamp": "2026-02-08T10:00:00Z",
      "commit": "ghi789"
    }
  ]
}
```

---

## Contradiction Detection (Progressive)

### Pass 1: Reference Validation (free, shell only)

Runs on every post-commit hook:

- Extract file references from AGENTS.md (`grep` for filenames with extensions)
- Verify each file exists on disk
- Extract command references (`grep` for build/test/run commands)
- Verify commands exist in package.json/Makefile/etc.

Catches: deleted files still documented, renamed commands, removed scripts.

### Pass 2: Export/API Surface Comparison (cheap, targeted reads)

Runs on session-start for Yellow+ directories:

- For files that changed since last verification, read exports/signatures only
- Compare against AGENTS.md descriptions
- Flag mismatches: "AGENTS.md says auth.ts exports validateJWT() but function renamed to verifyToken()"
- Uses tldrs if available for token-efficient extraction

### Pass 3: Claim Verification (expensive, subagent + optional Oracle)

Runs on scheduled/CI or manual request:

- Spawn verification subagent per flagged directory
- Subagent reads existing AGENTS.md and current code
- Produces claim-by-claim verification:

```json
{
  "schema": "interdoc.verification.v1",
  "directory": "src/api",
  "verified_claims": 12,
  "stale_claims": 3,
  "stale": [
    {
      "section": "Architecture",
      "claim": "Uses Express middleware stack",
      "reality": "Migrated to Hono in commit abc123",
      "confidence": "high"
    }
  ]
}
```

- If Oracle approved, send verification results through GPT for second opinion
- Combined agreement → auto-fix. Disagreement → unverified marker.

---

## Continuous Verification Loop

The system **converges toward accuracy over time.** Each run doesn't just check for new drift — it re-evaluates existing markers:

```
commit → structural fix (certain) → done
              |
              v (if semantic drift detected)
         add unverified marker
              |
              v (next session or scheduled run)
         re-analyze with more context
              |
              v
         verify (remove marker)
           OR fix with high confidence (replace + remove marker)
           OR still uncertain (marker stays, accumulates evidence)
```

Markers either get resolved or escalate. Over time, the number of unverified markers trends toward zero as the system gains evidence.

---

## Configuration: `.interdoc.yml`

```yaml
version: 1

# Drift detection behavior
drift:
  # What interdoc does at each confidence level
  certain_action: auto_fix          # auto_fix | propose | report
  high_action: auto_fix             # auto_fix | propose | report
  medium_action: mark_unverified    # auto_fix | mark_unverified | report
  low_action: mark_stale            # mark_stale | report | ignore

  # Trigger layers (which hooks are active)
  on_commit: true           # Layer 1: structural check after every commit
  on_session_start: true    # Layer 2: accumulated drift review
  on_pre_push: true         # Layer 3: informational summary
  scheduled: false          # Layer 4: full re-analysis (enable in CI)

  # Analysis depth per trigger
  commit_analysis: structural    # structural only (free)
  session_analysis: semantic     # structural + export comparison (some tokens)
  scheduled_analysis: full       # complete re-analysis (subagents + optional Oracle)

  # Thresholds
  staleness_warn_days: 14        # add stale marker after 2 weeks unverified
  staleness_critical_days: 30    # escalate after 1 month
  commit_threshold: 20           # flag after 20 commits without doc update

  # Auto-generation for new directories
  auto_generate: true            # generate AGENTS.md for new undocumented dirs
  auto_generate_threshold: 5     # minimum source files to trigger auto-generation

# Oracle/GPT review settings
oracle:
  auto_approve: false    # default: require human approval before Oracle runs
  run_on_session: false  # run Oracle review during session-start (if auto_approve)
  run_on_scheduled: true # run Oracle review during scheduled/CI runs
  timeout_minutes: 10    # Oracle timeout

# Scope control
scope:
  ignore_directories:    # skip these from all drift checks
    - node_modules
    - dist
    - .git
    - vendor
    - __pycache__
  watch_directories: []  # empty = watch all (minus ignores)
```

### Full Autopilot Config

For users who want zero-touch documentation:

```yaml
version: 1
drift:
  certain_action: auto_fix
  high_action: auto_fix
  medium_action: auto_fix       # aggressive: auto-fix medium too
  low_action: mark_unverified   # still mark, but less conservatively
  on_commit: true
  on_session_start: true
  scheduled: true
oracle:
  auto_approve: true            # Oracle runs without asking
  run_on_session: true          # review on every session start
```

### Conservative Config

For users who want visibility but minimal auto-changes:

```yaml
version: 1
drift:
  certain_action: auto_fix      # still auto-fix deterministic stuff
  high_action: propose          # propose everything else
  medium_action: report
  low_action: report
oracle:
  auto_approve: false
```

---

## Integration with Existing interdoc Features

| Existing Feature | Role in Self-Healing System |
|---|---|
| Change-set update mode | Powers session-start semantic analysis (only changed dirs) |
| Coverage report | Fed by drift.json — directories with `new_directory_no_docs` signal |
| Style lint | Runs on any AGENTS.md being auto-modified |
| Dry run + preview cache | Used internally for scheduled runs before applying |
| Parallel subagents | Semantic analysis (Pass 2/3) spawns subagents for flagged dirs |
| JSON schema output | Verification subagent uses same schema |
| CLAUDE.md harmonization | Drift system also checks for CLAUDE.md content drift |
| Review phase (auracoil) | Two-model verification loop for high-confidence auto-fixes |
| Oracle scripts | `oracle-review.sh`, `sanitize-review.sh`, `secret-scan.sh` used as-is |

---

## New Files Needed

| File | Purpose |
|---|---|
| `hooks/drift-scan.sh` | Shell script for structural drift detection (post-commit) |
| `hooks/drift-session.sh` | Session-start drift summary + semantic analysis trigger |
| `hooks/drift-prepush.sh` | Pre-push informational summary |
| `skills/interdoc/references/drift-detection.md` | Reference doc for detection engine |
| `skills/interdoc/references/drift-schema.json` | JSON schemas for drift.json, history.json |
| `skills/interdoc/references/self-healing.md` | Reference doc for self-healing workflow |

## Modified Files

| File | Changes |
|---|---|
| `skills/interdoc/SKILL.md` | Add self-healing workflow, drift detection, confidence tiers, `.interdoc.yml` config |
| `hooks/hooks.json` | Add PostToolUse:Bash (commit), SessionStart (drift), PreToolUse:Bash (push) hooks |
| `README.md` | Document self-healing system, configuration, setup |
| `AGENTS.md` | Update architecture and features |
| `.claude-plugin/plugin.json` | Version bump |

---

## Example: A Typical Week

**Monday — Developer commits 5 times:**
- Post-commit hook runs structural check each time (<1s each)
- Detects: 2 new files in `src/api`, 1 renamed file in `lib/core`
- Auto-fixes rename reference in `lib/core/AGENTS.md` (Certain)
- Auto-adds new files to `src/api/AGENTS.md` Key Files table (Certain)
- Creates 2 small doc-fixup commits
- Updates drift.json: `src/api` score = 2 (new files mentioned, but descriptions are generic)

**Tuesday — Developer opens Claude Code:**
- Session-start hook loads drift.json
- `src/api` has Yellow drift — runs semantic check on the 2 new files
- Reads their exports, generates proper descriptions
- Applies fix with `<!-- interdoc:unverified -->` marker (Medium confidence, no Oracle)
- Shows: `interdoc: 14 docs current, 1 unverified section (src/api)`

**Wednesday — Developer pushes:**
- Pre-push shows: `interdoc: 14 docs current, 1 unverified section`
- Suggests: `Run /interdoc review to verify with GPT? (y/n)`
- Developer says yes → Oracle reviews → GPT confirms the descriptions are accurate
- Marker removed, confidence upgraded to High
- Shows: `interdoc: 15 docs current`

**Friday — CI scheduled run:**
- Full re-analysis of all directories
- Finds `scripts/` AGENTS.md is 34 commits behind, architecture section outdated
- Generates updated content, sends through Oracle
- GPT confirms 2 of 3 changes, disagrees on 1
- Auto-applies confirmed changes, marks disagreement as unverified
- Drift report created as CI artifact

**Two weeks later — unverified marker still present:**
- Subsequent runs re-evaluate with more accumulated evidence
- After 3 more commits to `scripts/`, pattern is clearer
- Next scheduled run: Claude and GPT now agree → marker removed, content updated

---

## Resolved Design Questions

1. **Commit strategy:** Batch per session. Post-commit hook stages fixes into `pending-fixes.json` but doesn't commit. All accumulated fixes are applied as a single `docs(interdoc): auto-update stale references` commit at session end or pre-push. One clean commit per session instead of many.

2. **Marker format:** Inline HTML comments (`<!-- interdoc:unverified since=... reason="..." -->`). Invisible in rendered markdown, visible in raw. Precise — marks exactly what's uncertain. Agents reading raw markdown can factor the uncertainty into their decisions.

3. **Oracle batching:** Single batched prompt. All directories needing review go in one Oracle call — one approval prompt, one GPT context window. Output JSON is structured per-directory for parsing. GPT gets full cross-directory context which improves review quality.

4. **Cross-repo drift:** Per-repo independent. Each repo is a self-contained unit with its own `.interdoc.yml`, `.git/interdoc/` state, and hooks. No shared state across repos.
