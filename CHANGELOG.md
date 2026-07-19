# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`skillscore budget <path> ...`:** measure the always-on token cost of a set
  of skills. Every installed skill's `name` and `description` is loaded into the
  system prompt on every request so the agent can route, a cost paid whether or
  not the skill ever runs and one that grows with each skill added — until the
  listing is large enough that skills get silently dropped or mis-routed. The
  command reports the combined cl100k / Claude-estimated token cost, a per-skill
  breakdown largest-first, and flags any description that overflows the
  250-character routing window (rule `B6`). `--max-listing-tokens <n>` turns it
  into a CI gate that exits non-zero when the combined listing is over budget,
  and `--format json` emits the totals and per-skill entries. Fully offline and
  deterministic, reusing the same tiktoken counter as token-budget scoring.

## [0.10.0] - 2026-07-14

### Added

- **`--baseline <file>`:** adopt a strict CI gate on a fleet that already has
  findings, without fixing everything first (the idea behind ESLint bulk
  suppressions and Ruff's baseline). On first use it records the current
  findings to the file and exits 0; on later runs the gate fails only on
  findings that are **new** since the baseline was recorded. Findings are
  fingerprinted by `(relative path, rule id)`, so unrelated line shifts never
  invalidate the baseline, and info-level findings are out of scope. When a
  baseline is present it is the findings gate (it supersedes `--strict`) and the
  score is never changed, so pair it with `--min-score` for a score floor.
- **`--update-baseline`:** rewrite the baseline from the current findings after
  intentionally taking on new ones.

## [0.9.0] - 2026-07-09

### Added

- **`--fix` auto-remediation:** `skillscore <path> --fix` applies safe,
  mechanical corrections in place, then re-scores. The first fixer resolves
  rule A5: when a top-level frontmatter key is a confident "did you mean"
  match for a recognized key, it renames it (`descrption:` becomes
  `description:`). Fixes are deterministic and idempotent, preserve line
  endings and a leading BOM, and only ever touch a key with a near match.
- Auto-fixable findings now carry a green `[fixable]` marker in the pretty
  report, so the flag is discoverable.
- **CI/CD integration kit:** a reusable composite GitHub Action
  (`uses: sayed3li97/skillscore@v1`), a pre-commit hook
  (`.pre-commit-hooks.yaml`, system and Docker variants), a `Dockerfile` and
  a workflow that publishes the image to GHCR on release, and copy-paste
  configs for ten platforms (GitHub Actions, GitLab CI, CircleCI, Jenkins,
  Azure Pipelines, Bitbucket, Travis, Drone/Woodpecker, Google Cloud Build,
  pre-commit) under `docs/ci/`.
- A detailed [CI/CD guide](docs/ci/README.md) with the universal recipe, the
  exit-code contract, per-platform configs, the SARIF code-scanning
  integration, and a real GitHub Actions run whose findings surface in the
  Security tab.

### Changed

- The pretty reporter's "No findings" line no longer uses an em dash.
- Documentation: a rewritten README with animated SVG diagrams (pipeline,
  rubric, targets, eval, CI/CD), a new radial-rubric-ring cover, and premium
  terminal screenshots.

## [0.8.0] - 2026-07-04

### Added

- **Rule A5 (`A5_frontmatter_keys`):** flags any top-level `SKILL.md`
  frontmatter key outside the recognized set (`name`, `description`,
  `license`, `allowed-tools`, `metadata`, `version`). A misspelled key is
  invisible to YAML — `descrption:` silently drops the description while
  adding an unknown field — and strict validators such as Anthropic's
  `skill-creator` reject any unexpected key outright.
- When an unknown key is within edit distance two of a recognized key, the
  finding appends a "did you mean" suggestion (offline Levenshtein), so a
  typo like `descrption` points straight at `description`. Custom fields
  belong under the `metadata` map, which is never flagged (only top-level
  keys are checked).
- Parser now records the manifest line of every top-level frontmatter key,
  so A5 findings point at the offending key.
- README gains a "Catching frontmatter typos" section, and a full QA record
  with screenshot evidence lives in `docs/qa/a5/`.

### Note

- Version 0.7.0 was skipped: a tag was created in error by tooling and never
  published. This release supersedes it.

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
