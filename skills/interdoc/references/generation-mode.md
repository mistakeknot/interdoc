# Generation Mode Reference

This reference contains detailed workflows for fresh AGENTS.md generation.

## Directory Identification

### Source File Detection

Identify directories by source file extensions:

| Language | Extensions |
|----------|-----------|
| TypeScript | `.ts`, `.tsx`, `.mts`, `.cts` |
| JavaScript | `.js`, `.jsx`, `.mjs`, `.cjs` |
| Python | `.py`, `.pyi` |
| Go | `.go` |
| Rust | `.rs` |
| Java | `.java` |
| C/C++ | `.c`, `.cpp`, `.h`, `.hpp` |
| Ruby | `.rb` |
| PHP | `.php` |

### Package Manifest Detection

| Manifest | Language/Ecosystem |
|----------|-------------------|
| `package.json` | Node.js/npm |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml` | Python (modern) |
| `requirements.txt` | Python (legacy) |
| `setup.py` | Python (legacy) |
| `Gemfile` | Ruby |
| `composer.json` | PHP |
| `pom.xml` | Java/Maven |
| `build.gradle` | Java/Gradle |

### Threshold Rules

| Criterion | Threshold | Weight |
|-----------|-----------|--------|
| Has package manifest | N/A | Always include |
| Source file count | 5+ | Include |
| Has existing AGENTS.md | N/A | High priority |
| Structural directory | N/A | Consider (src/, lib/, etc.) |

## Subagent Spawning Strategy

### Concurrency Limits

| Project Size | Max Concurrent | Batch Size |
|--------------|---------------|------------|
| Small (<20 dirs) | 8 | All at once |
| Medium (20-50 dirs) | 12 | 12 per batch |
| Large (50+ dirs) | 16 | 16 per batch |

### Subagent Prompt Construction

```
Base prompt template:
1. Directory path
2. Mode (generation)
3. Security reminder
4. Output format specification

Optional context (if batch git collection succeeded):
5. Recent commits affecting this directory
6. Files changed since last documentation
```

## Consolidation Rules

### Deduplication

Patterns mentioned in 3+ directories move to root AGENTS.md:
- Pick the clearest description
- Note which directories share the pattern
- Remove from individual files (or link back)

### Cross-Reference Generation

When subagents report related concerns:
1. Identify relationships (A uses B, A extends B, etc.)
2. Add cross-references to root AGENTS.md
3. Add "See also" links in directory AGENTS.md files

### Terminology Harmonization

1. Extract terms from existing README if present
2. Build glossary of project-specific terms
3. Ensure consistent usage across all AGENTS.md files
