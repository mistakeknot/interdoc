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
| New files added | Medium | Add to Key Files |
| Files deleted | High | Update Key Files, check Architecture |
| File renamed | Low | Update Key Files |
| Content changed | Variable | Check if behavior changed |
| New dependency | High | Update Dependencies section |
| Config changed | Medium | Update Commands or Conventions |

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

## Stale Content Detection

### Common Staleness Indicators

| Indicator | Severity | Example |
|-----------|----------|---------|
| File referenced but deleted | High | "See `oldFile.ts`" but file gone |
| Outdated version numbers | Medium | "Requires Node 14" but package.json says 18 |
| Renamed function/class | Medium | "Call `initApp()`" but function renamed |
| Changed behavior | High | "Returns null on error" but now throws |

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
