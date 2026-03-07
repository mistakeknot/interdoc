# Changelog

## Recent Changes (January 2026)

### v4.4.3 - Phase 1 Roadmap: Coverage + Lint + Change-Set
- Added change-set update mode, coverage report, and style lint triggers
- Added optional local audit script (coverage + lint)

### v4.4.0 - Disable Hooks by Default
- Removed auto-loaded hooks to avoid Claude Code hook validation errors
- Manual invocation is the default workflow

### v4.3.3 - Dry Run + Preview Cache
- Added dry-run mode with summary + diff preview
- Added "apply last preview" cache (HEAD-validated)

### v4.3.2 - Claude Subagent + Codex Install
- Added interdocumentarian Claude subagent for directory docs
- Added Codex CLI install instructions

### v4.3.0 - Splinterpeer Robustness Improvements
- Rewrote hooks with repo-root handling and HEAD-tracking
- Added JSON schema with sentinel markers for subagent output
- Added deterministic CLAUDE.md heading allowlist
- Added scalability guardrails (concurrency limits, batching)
- Fixed find commands for filename safety
- Added comprehensive test plan

### v4.2.0 - CLAUDE.md Harmonization
- Initial CLAUDE.md → AGENTS.md migration feature

### v4.1.0 - Improved Verification and UX
- Better subagent verification before consolidation
- Individual file review option

---

*Last updated: 2026-01-18*
