# Interdoc

**Recursive CLAUDE.md generator using parallel subagents**

Interdoc generates and maintains CLAUDE.md documentation for your projects. It spawns parallel subagents to analyze each directory, then consolidates their findings into coherent documentation that helps coding agents understand your codebase.

## Features

- **Parallel subagents**: Spawns agents per directory for fast analysis
- **Smart scoping**: Each subagent decides if its directory warrants a CLAUDE.md
- **Consolidation**: Root agent deduplicates patterns and identifies cross-cutting concerns
- **Two modes**: Generation (new projects) and Update (existing documentation)
- **Cross-AI compatible**: Creates AGENTS.md redirects for Codex CLI

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
git clone https://github.com/mistakeknot/interdoc.git
cd interdoc
/plugin install .
```

## Usage

### Manual

Ask Claude to generate or update documentation:

```
"generate documentation for this project"
"create CLAUDE.md"
"update CLAUDE.md"
"document this codebase"
```

The skill automatically detects which mode to use:
- **No CLAUDE.md exists** → Generation mode (full recursive pass)
- **CLAUDE.md exists** → Update mode (analyze changes, update relevant sections)

### Automatic: Hooks

Interdoc includes hooks that prompt Claude to run the skill:

- **SessionStart**: Triggers when no CLAUDE.md exists or 3+ commits since last update
- **PostToolUse**: Triggers after 10+ commits accumulate mid-session

## How It Works

### Generation Mode

1. **Analyze structure** - Find directories with source files and package manifests
2. **Spawn subagents** - One per directory, running in parallel
3. **Each subagent**:
   - Reads source files, READMEs, configs
   - Extracts purpose, key files, patterns, conventions, gotchas
   - Decides if directory warrants its own CLAUDE.md
   - Returns structured output
4. **Consolidate** - Deduplicate patterns, harmonize terminology, identify cross-cutting concerns
5. **Write files** - Root CLAUDE.md + per-directory CLAUDE.md + AGENTS.md redirects
6. **Commit** - All documentation committed to git

### Update Mode

1. **Detect changes** - Find directories modified since last CLAUDE.md update
2. **Spawn targeted subagents** - Only for changed directories
3. **Analyze changes** - What's new, what's stale
4. **Present for approval** - User reviews proposed updates
5. **Apply and commit** - Update files, preserve existing content

## What Gets Documented

Subagents extract information useful for coding agents:

- **Purpose** - What does this code do?
- **Key files** - Important files and their roles
- **Architecture** - How components connect, data flow
- **Conventions** - Naming patterns, code style, structure
- **Dependencies** - What the code relies on
- **Gotchas** - Non-obvious behavior, known issues
- **Commands** - Build, test, run

## Directory Structure

```
interdoc/
├── .claude-plugin/
│   └── plugin.json         # Plugin metadata
├── hooks/
│   ├── hooks.json          # Hook configuration
│   ├── check-updates.sh    # SessionStart hook
│   └── check-commit.sh     # PostToolUse hook
├── skills/
│   └── interdoc/
│       └── SKILL.md        # Main skill definition
└── README.md
```

## Example

### New Project

```
User: generate documentation for this project

Claude: I'll generate CLAUDE.md documentation for this project.

Analyzing project structure...
Found 4 directories to document:
- / (root)
- /src/api/
- /src/core/
- /packages/shared/

Spawning subagents to analyze each directory...

[Subagents run in parallel]

Consolidation complete. Created:
- /CLAUDE.md (root documentation)
- /src/api/CLAUDE.md
- /packages/shared/CLAUDE.md
- AGENTS.md redirects for each

Committed: "Generate CLAUDE.md documentation"
```

### Existing Project

```
User: update CLAUDE.md

Claude: CLAUDE.md exists. Checking for changes...

Found 5 commits affecting 2 directories:
- /src/api/ (3 files changed)
- /src/core/ (2 files changed)

Proposed updates:

1. /src/api/CLAUDE.md
   Add section: "Rate Limiting"

2. Root CLAUDE.md
   Update section: "Architecture"

Apply these updates? (yes/review/skip)
```

## Design Principles

1. **Useful for agents** - Document what helps coding agents be effective
2. **Parallel execution** - Spawn subagents concurrently for speed
3. **Human approval** - User approves all changes in update mode
4. **Preserve customizations** - Don't overwrite user edits
5. **Cross-AI compatible** - AGENTS.md for Codex CLI

## License

MIT License

## Author

MK (mistakeknot@vibeguider.org)
