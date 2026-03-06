# Update Mode Reference

This reference contains detailed workflows for incremental AGENTS.md updates.

## Change Detection

### Git History Analysis

Using batch-collected context (from Step 0):

```
For each directory with AGENTS.md:
1. Get AGENTS.md last-modified commit
2. Get all commits since then
3. Filter commits that touch this directory
4. Extract file changes and commit messages
```

### Skip Conditions

Skip a directory if:
- No commits since AGENTS.md was updated
- Only non-source files changed (.md, .json config, etc.)
- Changes are in excluded patterns (tests/, docs/)

### Change Classification

| Change Type | Impact | Action |
|-------------|--------|--------|
| New files added | Low | No action if covered by discovery commands (e.g., `ls src/`) |
| Files deleted | Low | No action if covered by discovery commands |
| File renamed | Low | No action if covered by discovery commands |
| Content changed | Variable | Check if behavior/architecture changed (static prose) |
| New dependency | Low | No action if covered by discovery command (e.g., `cat Cargo.toml`) |
| Config changed | Medium | Update Commands or Conventions (static) |
| New design concept | High | Add to Architecture section (static prose) |
| New gotcha discovered | High | Add to Gotchas section (static prose) |

> **Note:** Most file-level changes no longer require AGENTS.md updates because volatile content (file trees, struct fields, dependency versions) is represented as discovery commands, not static listings. Only update static sections when design decisions, conventions, or gotchas change.

## Operation Types

### add_section

Add a new section to an AGENTS.md file.

```json
{
  "op": "add_section",
  "heading": "Recent Updates (January 2026)",
  "position": "after:Gotchas",
  "content": "### New Feature\n- Description"
}
```

Position values:
- `after:SectionName` - Insert after specified section
- `before:SectionName` - Insert before specified section
- `end` - Append to end of file

### append_to_section

Add items to an existing section (for lists/tables).

```json
{
  "op": "append_to_section",
  "heading": "Key Files",
  "items": [
    "| `newFile.ts` | Description |",
    "| `another.ts` | Description |"
  ]
}
```

### replace_in_section

Replace specific text within a section.

```json
{
  "op": "replace_in_section",
  "heading": "Architecture",
  "find": "uses SQLite for storage",
  "replace": "uses PostgreSQL for storage",
  "context_before": "The service",
  "context_after": "and handles"
}
```

Rules:
- Must have exactly one match
- Context helps disambiguate multiple potential matches
- If no match or multiple matches, report error

### delete_section

Remove a section entirely.

```json
{
  "op": "delete_section",
  "heading": "Deprecated Features",
  "reason": "Feature removed in commit abc123"
}
```

### convert_to_discovery

Replace a static section with discovery commands. This is the most important update operation — it eliminates staleness permanently.

```json
{
  "op": "convert_to_discovery",
  "heading": "Key Files",
  "reason": "Static file table goes stale on every commit",
  "discovery_commands": [
    { "label": "source files", "command": "ls src/" },
    { "label": "test files", "command": "ls tests/" }
  ]
}
```

This removes the static section content and adds the commands to the "Discovering the Codebase" section (creating it if needed).

## Stale Content Detection

### Common Staleness Indicators

| Indicator | Severity | Example |
|-----------|----------|---------|
| Static file listing exists | High | Replace with discovery command (`ls`, `find`) |
| Static struct/enum table exists | High | Replace with discovery command (`grep`) |
| Static dependency version table | High | Replace with discovery command (`cat Cargo.toml`) |
| File referenced but deleted | Medium | Fix cross-reference in static prose |
| Renamed function/class | Medium | "Call `initApp()`" but function renamed |
| Changed behavior | High | "Returns null on error" but now throws |

> **Upgrade path:** When updating an AGENTS.md that has static enumerations (file trees, struct tables, version tables), convert them to discovery commands. This is the highest-value update operation — it makes the doc permanently accurate.

### Stale Content Report Format

```json
{
  "stale_content": [
    {
      "heading": "Architecture",
      "issue": "References OldService which was renamed to NewService",
      "suggestion": "Update all references from OldService to NewService"
    }
  ]
}
```

## Preservation Rules

When updating AGENTS.md:

1. **Never remove** user's manual additions (identified by non-standard sections)
2. **Append** new content rather than replacing when possible
3. **Keep** formatting and custom structure
4. **Add** "Last Updated: YYYY-MM-DD" at bottom
5. **Preserve** any `<!-- interdoc:keep -->` marked content
