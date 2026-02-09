# CLAUDE.md

> **Documentation is in AGENTS.md** - This file contains Claude-specific settings only.
> For project documentation, architecture, and conventions, see [AGENTS.md](./AGENTS.md).

## Claude-Specific Settings

When working on this repo, Claude should:

- **Remind user to bump version** after committing changes to SKILL.md or hooks — use `/interpub:release <version>` or `scripts/bump-version.sh <version>`
- **Update the marketplace** — both tools above handle this automatically
- Use the Read tool instead of cat for file operations
- Prefer Edit tool over sed/awk for file modifications

## Workflow Reminders

After pushing changes to interdoc:
1. Update `~/interagency-marketplace/.claude-plugin/marketplace.json`
2. Commit and push marketplace changes
3. Run `claude plugin marketplace update interagency-marketplace`
4. Run `claude plugin update interdoc@interagency-marketplace`

## See Also

- [AGENTS.md](./AGENTS.md) - Full project documentation, architecture, development guide
- [README.md](./README.md) - User-facing installation and usage guide
- [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) - Test cases from splinterpeer analysis
