# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-12

### Added

- Initial release of `skillscore`.
- 24 scoring rules across 7 rubric categories (A frontmatter, B
  description, C conciseness, D structure, E instruction quality, F
  hygiene, G safety penalty), each citing its source authoring guide
  (Anthropic, Antigravity, Codex, Flutter).
- Target profiles: `--target claude | antigravity | codex | universal`
  implemented as data (per-target rule activation + severity overrides).
- Name-agnostic, case-insensitive skill discovery for single manifests,
  skill folders, and whole directory trees; BOM/CRLF tolerance; graceful
  handling of malformed frontmatter, binary files, and symlinks.
- Reporters: `pretty` (colored, per-category bars), `json` (stable CI
  shape), and `sarif` (valid SARIF 2.1.0).
- CI gating via `--min-score` and `--strict`; exit codes 0/1/2.
- `skillscore rules` and `skillscore explain <rule-id>` with rationale,
  fix, and source citations.

[0.1.0]: https://github.com/sayed3li97/skillscore/releases/tag/v0.1.0
