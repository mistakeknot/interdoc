# interdoc Codex CLI Install

This installs the interdoc skill for Codex CLI by copying the skill folder.

## Prerequisites

- Codex CLI installed and logged in:
  ```bash
  npm install -g @openai/codex
  codex login
  ```

## Install (user-wide)

```bash
mkdir -p ~/.codex/skills
rm -rf ~/.codex/skills/interdoc
cp -R "$(pwd)/skills/interdoc" ~/.codex/skills/interdoc
```

## Install (repo-local, optional)

Use this if you want the skill available only in this repo:

```bash
mkdir -p .codex/skills
rm -rf .codex/skills/interdoc
cp -R "$(pwd)/skills/interdoc" .codex/skills/interdoc
```

## Update

Re-run the install command above to refresh the skill.

## Uninstall

```bash
rm -rf ~/.codex/skills/interdoc
# or, if installed repo-local:
rm -rf .codex/skills/interdoc
```

## Use

In Codex, ask:

"Generate AGENTS.md for this project"
