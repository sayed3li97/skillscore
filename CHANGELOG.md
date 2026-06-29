# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-06-29

### Added

- **Eval harness:** new `skillscore eval` command family for testing skill trigger accuracy without an API key.
  - `eval init <path>` — scaffolds an `evals.json` file with 20 default queries derived from the skill description.
  - `eval validate <path>` — parses and validates the eval suite; enforces trigger/non-trigger balance and minimum query count.
  - `eval run <path>` — runs the full suite using the offline `HeuristicEvalClient`; exits 0 for pass, 1 for gate failure, 2 for usage errors.
- **HeuristicEvalClient:** fully offline, deterministic trigger scorer.
  - Extracts trigger terms (`use when` clause), boundary terms (`do not use` clause), and what-terms (first sentence) from the skill description.
  - Boundary-exclusivity logic: only terms unique to the boundary clause penalize a query — shared nouns never cause false negatives.
  - Meta-query pattern: `what is`, `explain`, `write a test for`, `summarise`, `debug why`, and similar explainer queries never trigger.
  - Wave noise (±7%, deterministic per call index) adds realistic variance without randomness.
- **B6 description truncation rule:** warns when the skill description field is too long for reliable discovery.
- **C1 fix hint:** improved hierarchy pointer in the fix hint for conciseness rule C1.
- `--format json` output for `eval run` includes `skill`, `passed`, `failed`, `queries`, and per-query results.
- QA test suite (`tool/qa_run.mjs`): 20 test cases covering all three eval subcommands with PNG terminal screenshots in `docs/qa/evidence/`.

## [0.3.0] - 2026-06-14

### Added

- **BPE token counting:** every scorecard now shows the token cost of each
  skill split into two scopes:
  - `description (permanent)` — loaded on every prompt for skill discovery
  - `full manifest (active)` — loaded only when the skill is invoked
- Token counts use the **cl100k_base** BPE vocabulary (exact for GPT-4 and
  Codex; Claude estimates add 10% overhead).
- `--format json` output gains a `tokens` key with `gpt4` and
  `claudeEstimate` values for both scopes, ready for dashboards and CI.
- Validated against the official Anthropic `count_tokens` API across all
  31 skills in `google/skills`: mean actual Claude overhead +10.2%,
  median exactly +10.0%, range +0% to +20%.

## [0.2.0] - 2026-06-13

### Added

- **Multi-path scoring:** pass two or more paths in one command and get a
  combined report with a summary line:
  `skillscore skill-a/ skill-b/ skill-c/`
- Duplicate manifests are silently deduplicated, so overlapping paths
  (e.g. a tree root and one of its children) are each scored once.
- When multiple paths are given and one is invalid or contains no
  manifest, the CLI warns on stderr and scores the remaining paths
  rather than aborting. All paths invalid still exits with code 2.
- Usage string updated to reflect `<path> [<path> ...]`.

## [0.1.1] - 2026-06-12

### Changed

- Documentation only: the README now leads with a cover banner and a
  terminal demo GIF (scoring the Flutter team's `flutter-add-widget-test`
  skill at 90/A, then explaining a finding with its source guide). Images
  are served from `raw.githubusercontent.com` so they render on pub.dev.
  No code or behavior changes.

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

[0.2.0]: https://github.com/sayed3li97/skillscore/releases/tag/v0.2.0
[0.1.1]: https://github.com/sayed3li97/skillscore/releases/tag/v0.1.1
[0.1.0]: https://github.com/sayed3li97/skillscore/releases/tag/v0.1.0
