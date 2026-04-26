---
name: interdoc
description: "Generate, update, and review AGENTS.md with Oracle critique."
---

# /interdoc

Run the `interdoc-engine` skill to generate, update, and review AGENTS.md for this repository.

This command should:
- Detect whether AGENTS.md exists
- Generate AGENTS.md if missing
- Update AGENTS.md if present
- Send to Oracle for independent critique (if available)
- Apply non-controversial improvements silently
- Prompt for significant changes
- Use dry-run mode only when the user explicitly asks
