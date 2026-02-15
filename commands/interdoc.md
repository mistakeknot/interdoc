# /interdoc

Run the interdoc skill to generate, update, and review AGENTS.md for this repository.

This command should:
- Detect whether AGENTS.md exists
- Generate AGENTS.md if missing
- Update AGENTS.md if present
- Send to GPT 5.2 Pro for critique (if Oracle available)
- Apply non-controversial improvements silently
- Prompt for significant changes
- Use dry-run mode only when the user explicitly asks
