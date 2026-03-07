# Development & Versioning

## Development

### This is Documentation-Driven

There is **no source code** to build or test. The "implementation" is the skill documentation and shell scripts.

**To modify behavior:**
- Edit `skills/interdoc/SKILL.md` to change workflows
- Edit `hooks/*.sh` to change trigger logic
- Update `README.md` for user-facing documentation
- Update `.claude-plugin/plugin.json` for metadata/version changes

### Testing Changes

1. Make changes to SKILL.md or hook files
2. Commit and push to GitHub
3. Run `claude plugin update interdoc@interagency-marketplace` to refresh local cache
4. Trigger the skill to verify behavior

See `docs/TEST_PLAN.md` for comprehensive test cases.

## Version Management

**Version is declared in `.claude-plugin/plugin.json` (root level).**

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Bug fix, docs clarification | Patch | 4.3.0 → 4.3.1 |
| New feature, workflow change | Minor | 4.3.0 → 4.4.0 |
| Breaking change | Major | 4.3.0 → 5.0.0 |

### Bump Version

After committing skill changes:

```bash
# 1. Edit plugin.json and increment version
# 2. Commit and push
git add .claude-plugin/plugin.json
git commit -m "Bump version to X.Y.Z"
git push
```

### Update the Marketplace

The plugin is distributed via `interagency-marketplace`. After pushing version changes:

1. Edit `~/interagency-marketplace/.claude-plugin/marketplace.json`
2. Update the `interdoc` entry version
3. Commit and push
4. Refresh local cache:
   ```bash
   claude plugin marketplace update interagency-marketplace
   claude plugin update interdoc@interagency-marketplace
   ```

## Commit Workflow

1. Edit the relevant files (SKILL.md, hooks, etc.)
2. Commit with descriptive message
3. **Bump version in plugin.json**
4. Commit version bump
5. Push both commits
6. **Update ~/interagency-marketplace** with new version
7. Push marketplace changes
