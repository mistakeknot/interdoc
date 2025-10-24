# Interdoc

**Keep CLAUDE.md documentation up-to-date automatically**

Interdoc is a Claude Code plugin that detects significant code changes and suggests relevant CLAUDE.md documentation updates. It reduces manual maintenance burden while keeping humans in control.

## Features

- **Automatic detection**: Post-commit hook identifies significant changes
- **Smart categorization**: Groups changes into Architecture, Implementation, Dependencies, and Conventions
- **Non-intrusive workflow**: Batches suggestions, doesn't interrupt rapid iteration
- **Mono-repo support**: Handles multiple CLAUDE.md files intelligently
- **Cross-AI compatibility**: Automatically creates AGENTS.md redirects for Codex CLI

## Installation

### From Marketplace

```bash
# Add the interagency marketplace (if not already added)
/plugin marketplace add mistakeknot/interagency-marketplace

# Install Interdoc
/plugin install interdoc
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/mistakeknot/interdoc.git

# Install the plugin
cd interdoc
/plugin install .
```

## Usage

### Automatic (Recommended)

The post-commit hook automatically detects significant changes:

```bash
git commit -m "Add new authentication system"
# Hook detects: new files, architectural changes
# Logs for later review

# After 3+ significant commits:
💡 Tip: 3 commits may need CLAUDE.md updates
   Run: 'update CLAUDE.md' to review
```

### Manual Invocation

Review pending updates anytime:

```
update CLAUDE.md
```

or

```
review documentation
```

Claude will analyze commits since the last CLAUDE.md update and suggest relevant additions.

## What Gets Documented

Interdoc suggests updates for:

### Architecture Changes
- New directories or major reorganization
- Changes to build/config files
- New file types (tech stack changes)

### Implementation Details
- Bug fixes with non-obvious solutions
- Complex logic or workarounds
- Performance optimizations
- Important gotchas

### Dependencies
- New packages or libraries
- Dependency updates
- Plugin additions

### Conventions
- Consistent patterns across multiple files
- New naming or structure patterns
- Workflow changes

## Workflow

1. **Detection**: Hook identifies significant commits
2. **Batching**: Suggestions accumulate without interruption
3. **Review**: User runs manual review when ready
4. **Categorization**: Claude groups changes by category
5. **Suggestions**: Proposed updates match existing CLAUDE.md style
6. **Approval**: User approves, edits, or rejects each suggestion
7. **Application**: Claude updates CLAUDE.md and creates AGENTS.md
8. **Commit**: Documentation changes committed to git

## Edge Cases Handled

### Missing CLAUDE.md

Interdoc offers to create a minimal template:

```markdown
# CLAUDE.md

## Repository Purpose
## Architecture
## Current Status
## Key Conventions
```

### Mono-repos

Automatically detects mono-repo structure and creates CLAUDE.md files per package:

```
packages/api/CLAUDE.md
packages/shared/CLAUDE.md
./CLAUDE.md (root)
```

Updates target the appropriate file based on changed code.

### Large Refactors

For massive changes (>50 files), focuses on architectural patterns rather than overwhelming detail.

### Merge Commits

Analyzes the combined merge diff and flags large merges for review.

## Cross-AI Compatibility

Interdoc automatically creates AGENTS.md files for Codex CLI compatibility:

```markdown
# Agent Context

For complete project documentation, read CLAUDE.md in this directory.

This file exists for Codex CLI compatibility. All project guidance,
architecture, conventions, and lessons learned are maintained in CLAUDE.md.
```

This enables seamless use of both Claude Code and Codex CLI on the same codebase with a single source of truth.

## Configuration

### Adjusting Sensitivity

Edit `.git/hooks/post-commit` to tune detection thresholds:

```bash
# Trigger on N+ files (default: 3)
if [ "$FILES_CHANGED" -ge 3 ]; then
    SIGNIFICANT=1
fi
```

### Reminder Frequency

Adjust when reminders appear:

```bash
# Show at these pending counts (default: 3, 5, 10)
if [ "$PENDING" -eq 3 ] || [ "$PENDING" -eq 5 ] || [ "$PENDING" -eq 10 ]; then
```

## Design Philosophy

1. **Human control**: You approve all changes
2. **Non-intrusive**: Never interrupts your flow
3. **Context-aware**: Matches your CLAUDE.md style
4. **Helpful defaults**: Creates files, handles edge cases automatically
5. **Apply judgment**: Not every change needs documentation

## Examples

### After Feature Implementation

```
You: update CLAUDE.md

Claude: I've analyzed 8 commits since the last update (3 days ago).

Found 2 categories of changes:

1. 🏗️  Architecture: New authentication system
   - Added JWT middleware
   - Created auth/ directory structure

2. 📦 Dependencies: Redis integration
   - Added redis and ioredis packages
   - Configured session storage

Would you like to review suggestions?

You: yes

Claude: [Shows detailed suggestions for each category]

## Architecture: New Authentication System

**Commits**:
- abc123: Add JWT middleware
- def456: Create user auth flow

**Proposed Documentation**:

### Authentication System

The application uses JWT-based authentication with refresh tokens.
Key components:
- `auth/middleware.ts` - JWT verification
- `auth/tokens.ts` - Token generation and refresh
- Session data stored in Redis for scalability

**Why this matters**:
Future work on auth should follow this JWT pattern. Refresh tokens
expire after 7 days and require re-authentication.

---
Add to CLAUDE.md? (yes/no/edit)
```

### Mono-repo Detection

```
You: update CLAUDE.md

Claude: I detected this is a mono-repo.

Your recent commits affected:
- packages/api/ (3 commits)
- packages/ui/ (2 commits)

I'll update:
- packages/api/CLAUDE.md (API-specific changes)
- packages/ui/CLAUDE.md (UI-specific changes)

[Proceeds with suggestions for each package]
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Author

MK (mistakeknot@vibeguider.org)

## Links

- [GitHub Repository](https://github.com/mistakeknot/interdoc)
- [Interagency Marketplace](https://github.com/mistakeknot/interagency-marketplace)
- [Claude Code Documentation](https://docs.claude.com/claude-code)
