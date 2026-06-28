# skillscore — lint and score AI agent skills (SKILL.md)

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/cover.png" alt="skillscore — score your AI agent's SKILL.md 0 to 100 against the Claude, Codex, and Antigravity authoring guides" width="100%">
</p>

[![CI](https://github.com/sayed3li97/skillscore/actions/workflows/ci.yml/badge.svg)](https://github.com/sayed3li97/skillscore/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/skillscore.svg)](https://pub.dev/packages/skillscore)
[![VS Marketplace](https://img.shields.io/visual-studio-marketplace/v/sayed-ali-alkamel.skillscore?label=VS%20Marketplace&color=blue)](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore)
[![Open VSX](https://img.shields.io/open-vsx/v/sayed-ali-alkamel/skillscore?label=Open%20VSX&color=purple)](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore)
[![license: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**skillscore** statically analyzes any AI agent skill — a `SKILL.md` manifest
and its folder — and produces a **0–100 quality score**, a **letter grade**,
and a list of **actionable findings**, scored against the official skill
authoring guides from **Anthropic (Claude)**, **Google (Antigravity)**, and
**OpenAI (Codex)**. Offline, deterministic, CI-friendly.

## What is skillscore?

skillscore is a **skill linter / SKILL.md validator / agent-skill quality
checker / AI skill scorer**. Agent skills are an open standard — a folder
with a `SKILL.md` (YAML frontmatter + Markdown body) plus optional
`references/`, `examples/`, `scripts/`, and `assets/` — used by Claude Code,
Codex, Antigravity, Gemini CLI, and Cursor. Because an agent keeps every
skill's `name` and `description` in its context budget permanently, **a vague
or malformed skill is worse than no skill**. skillscore catches exactly those
problems before a skill ships.

## See it in action

Score a single skill — here, the Flutter team's own `flutter-add-widget-test`
(90/A) — with a full per-category breakdown and cited findings:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/skillscore-demo.gif" alt="Terminal recording: skillscore scores the Flutter team's flutter-add-widget-test skill 90 out of 100 grade A with per-category bars and two findings, then skillscore explain shows the rule rationale and its Flutter authoring-guide source" width="85%">
</p>

Or scan several skills at once and drill into the lowest scorer — here,
three skills from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills):

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/multipath-demo.gif" alt="Terminal recording: skillscore scores three agent-skills in one command (spec-driven-development 91/A, test-driven-development 88/B, performance-optimization 77/C), then a second command drills into performance-optimization showing the missing Safety section error and vague description warning" width="85%">
</p>

## Token budget

Every scorecard now includes the BPE token cost of each skill, split by the two scopes in which agent runtimes load SKILL.md content:

```text
  Tokens  description (permanent)    67 gpt-4   ~74 claude
          full manifest (active)   1474 gpt-4  ~1622 claude
```

**Permanent** is the per-prompt cost — the agent loads the `description` field on every call so it knows which skills exist. **Active** is the per-invocation cost, paid only when the agent decides to use the skill.

The counts use the **cl100k_base** BPE vocabulary (exact for GPT-4 and Codex; Claude estimates add 10% overhead).

Tested on all 31 skills from [google/skills](https://github.com/google/skills):

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/token-demo.gif" alt="Terminal recording: skillscore scans all 31 Google skills, then drills into the top scorer (95/A, 67-token description) and the lowest scorer (56/F, 142-token description), showing token counts alongside each scorecard" width="85%">
</p>

Description token counts across the Google skills repo ranged from **24 to 142** — a 6x spread. The 56/F `gke-basics` skill pays 142 tokens on every prompt just for discovery, while the 95/A `agent-platform-tuning-management` skill pays 67. Less tokens, better score, better skill.

Token counts also appear in `--format json` under a `tokens` key, making them available to dashboards and CI pipelines.

### API-validated accuracy

The +10% Claude estimate was validated against the official **Anthropic `count_tokens` API** across all 31 Google skills:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/validate-demo.gif" alt="Terminal recording: skillscore estimate for gke-basics followed by the Anthropic count_tokens API validation across all 31 Google skills, showing mean overhead of +10.2% and median of +10.0%" width="85%">
</p>

| Metric | Value |
|---|---|
| Skills validated | 31 (all of google/skills) |
| Mean actual Claude overhead vs cl100k | +10.2% |
| Median | +10.0% |
| Range | +0% to +20% (varies with keyword density) |

The heuristic is accurate on average. Individual skills with dense trigger-keyword lists in their descriptions (like `gke-basics`) run toward +18-20%; clean prose descriptions run toward 0-6%.

## Editor integration

Prefer to score inside your IDE? The **[Skillscore VS Code extension](https://github.com/sayed3li97/skillscore-vscode)** wraps this CLI and adds inline diagnostics, hover tooltips, a sidebar score panel, and a live status-bar indicator — available for VS Code, Antigravity IDE, VSCodium, and Cursor.

Install from the [VS Marketplace](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore) or [Open VSX](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore).

---

## Quickstart

```bash
# Install
dart pub global activate skillscore

# Score a single skill (any name, any location)
skillscore path/to/SKILL.md

# Score every skill in a folder or monorepo
skillscore path/to/skills/

# Score multiple specific skills in one command
skillscore skill-a/ skill-b/ skill-c/

# Pick a target ruleset
skillscore my-skill/ --target claude

# Machine-readable output for CI / dashboards
skillscore my-skill/ --format json

# Gate CI: fail the build if any skill scores below 80
skillscore skills/ --min-score 80
```

Sample output (trimmed):

```text
csv-to-xlsx  (skills/spreadsheet-skill/SKILL.md)
  Score: 72/100  Grade: C

  Tokens  description (permanent)    22 gpt-4   ~25 claude
          full manifest (active)    185 gpt-4  ~204 claude

  A  Frontmatter validity                     15/15  ██████████
  B  Description quality                      12/25  █████░░░░░
  C  Conciseness & token economy            10.5/15  ███████░░░
  D  Structure & progressive disclosure       15/15  ██████████
  E  Instruction quality                       9/20  █████░░░░░
  F  Content hygiene                          10/10  ██████████
  G  Safety & scripts                    no penalty

  WARNING B2_description_when  line 3
          Description has no trigger clause saying when to use the skill.
          fix: Add a trigger clause such as "Use when the user asks to ..."
```

## Commands and flags

```text
skillscore <path> [<path> ...]        Score one or more manifests, folders, or trees
skillscore rules                      List every rule: id, title, weight, targets, source guide
skillscore explain <rule-id>          Print a rule's rationale, the fix, and its source guide
skillscore eval init <path>           Scaffold evals.json from the skill's description
skillscore eval validate <path>       Validate and summarise evals.json
skillscore eval run <path>            Run the trigger-rate eval protocol against the API
skillscore --version
skillscore --help
```

| Flag | Values | Default | Purpose |
|---|---|---|---|
| `--target` | `claude` \| `antigravity` \| `codex` \| `universal` | `universal` | Which guide's ruleset to apply |
| `--format` | `pretty` \| `json` \| `sarif` | `pretty` | Output format (SARIF 2.1.0 renders in code-review tools) |
| `--min-score <n>` | 0–100 | — | Exit non-zero if any skill scores below `n` |
| `--strict` | — | off | Treat warning-level findings as errors |
| `--quiet` | — | off | Print only the final score line per skill |
| `--no-color` | — | off | Disable ANSI colors |

**Exit codes:** `0` all skills meet the threshold · `1` a skill is below
`--min-score`, or `--strict` and any error/warning exists · `2` usage error
(bad path, unreadable file, invalid flag).

## How is the score calculated?

100 points are distributed across categories A–F. Each rule awards full,
partial, or zero points; partial-credit formulas are documented in each
rule's doc comment and shown by `skillscore explain <id>`. Category G
(safety) is a **penalty** of up to −15 that applies only when the skill
ships scripts or terminal commands. Profiles that exclude a rule (e.g.
`--target claude` excludes the Codex-specific B4) are normalized back to a
0–100 scale, so scores are comparable across targets.

**Grades:** A 90–100 · B 80–89 · C 70–79 · D 60–69 · F below 60.

### The full rubric

| Rule | Title | Pts | Severity | Targets | Source |
|---|---|---|---|---|---|
| `A1_frontmatter_present` | YAML frontmatter delimited by `---` | 4 | error | all | Anthropic |
| `A2_name_format` | `name` ≤64 chars, lowercase/digits/hyphens | 4 | error | all | Anthropic |
| `A3_name_reserved_words` | `name` avoids "anthropic"/"claude" | 3 | error (claude) / info | all | Anthropic |
| `A4_description_present` | `description` present, ≤1024 chars | 4 | error | all | Anthropic |
| `B1_description_what` | States WHAT (opens with action verb) | 6 | warning | all | Anthropic |
| `B2_description_when` | States WHEN ("use when ...") | 6 | warning | all | Anthropic |
| `B3_third_person` | Written in third person | 5 | warning | all | Anthropic |
| `B4_frontloaded_triggers` | Concrete keywords in first ~60 chars | 4 | warning | codex, universal | Codex |
| `B5_boundary_clause` | Has a "do not use" boundary | 4 | warning (antigravity) / info | antigravity, universal | Antigravity |
| `C1_body_length` | Body ≤500 lines (linear to 0 at 1000) | 6 | warning | all | Anthropic |
| `C2_explainer_bloat` | No definitions of common knowledge | 5 | warning | all | Anthropic |
| `C3_excessive_optionality` | No long "or" chains | 4 | info | all | Anthropic |
| `D1_progressive_disclosure` | Depth split into references/examples | 5 | info | all | Anthropic |
| `D2_one_level_links` | Reference links one level deep | 5 | warning | all | Anthropic |
| `D3_reference_toc` | Long reference files have a TOC | 5 | info | all | Anthropic |
| `E1_anti_patterns` | States anti-patterns explicitly | 6 | warning | all | Flutter |
| `E2_workflow_checklist` | Checklist or numbered workflow | 5 | warning | all | Anthropic |
| `E3_feedback_loop` | Validate → fix → repeat loop | 5 | warning | all | Anthropic |
| `E4_code_example` | At least one fenced code example | 4 | warning | all | Anthropic |
| `F1_time_sensitive` | No date-anchored statements that rot | 4 | warning | all | Anthropic |
| `F2_forward_slashes` | Paths use forward slashes only | 3 | error | all | Anthropic |
| `F3_consistent_terminology` | No synonym mixing (conservative) | 3 | info | all | Anthropic |
| `G1_safety_section` | Scripts/commands need a Safety section | −8 | error | antigravity, universal | Antigravity |
| `G2_script_docs` | Bundled scripts are documented | −7 | warning | all | Anthropic |

Run `skillscore rules` for the live table and
`skillscore explain <rule-id>` for any rule's rationale and fix.

## Eval harness

Static linting tells you a skill is well-formed. The eval harness tells you
**whether the model actually routes to it** — the thing that matters in
production. Three subcommands, one workflow:

```bash
# 1. Scaffold evals.json next to SKILL.md (runs offline, no API key needed)
skillscore eval init my-skill/

# 2. Review and optionally extend the generated queries
cat my-skill/evals.json

# 3. Run the eval against the Anthropic API
ANTHROPIC_API_KEY=sk-ant-… skillscore eval run my-skill/
```

**`eval init`** reads the skill's description and derives 20 queries — 10
trigger (the model should pick this skill) and 10 non-trigger (it should not).
Every query is a real English sentence based on the skill's trigger clause and
boundary clause; the file is runnable immediately while being easy to extend
with project-specific queries.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/eval-init.png" alt="Terminal: skillscore eval init pdf-form-filler/ — Created pdf-form-filler/evals.json, 20 queries scaffolded" width="85%">
</p>

**`eval validate`** parses `evals.json`, checks it has both trigger and
non-trigger queries, and prints a structured summary of the test suite.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/eval-validate.png" alt="Terminal: skillscore eval validate pdf-form-filler/ — shows skill name, 10 trigger + 10 non-trigger, model, threshold, 60 total API invocations" width="85%">
</p>

**`eval run`** fires 20 queries × 3 runs = 60 API calls (bounded at 5
concurrent), streams live progress, then prints a per-query PASS/FAIL report.
A trigger query passes when the model picks the skill in at least 50% of runs;
a non-trigger query passes when it stays below 50%. FAILs on non-trigger
queries tell you exactly which phrasings cause false positives — and which
boundary clause to tighten.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/eval-run.png" alt="Terminal: skillscore eval run pdf-form-filler/ — live progress, then per-query PASS/FAIL table, 13 passed 7 failed with failure details" width="85%">
</p>

**`--format json`** on `eval run` emits a machine-readable result for
dashboards and CI pipelines.

The API key is read from `ANTHROPIC_API_KEY` or `~/.config/anthropic/api_key`.
The default model is `claude-haiku-4-5-20251001` to keep eval costs low
(roughly $0.003 per 60-call run).

## How do I gate CI on skill quality?

```yaml
# .github/workflows/skills.yml
- name: Lint agent skills
  run: |
    dart pub global activate skillscore
    skillscore skills/ --min-score 80 --no-color
```

`--format json` feeds dashboards; `--format sarif` uploads to GitHub code
scanning so findings annotate pull requests.

## FAQ

**What is an agent skill?**
A folder with a `SKILL.md` manifest (YAML frontmatter + Markdown
instructions) that teaches an AI agent a repeatable task. Optional
subfolders hold references, examples, scripts, and assets.

**Does skillscore work with Claude Code / Codex / Antigravity / Gemini CLI / Cursor?**
Yes. The SKILL.md format is shared across all of them. Score against one
vendor's rules with `--target`, or use the default `universal` profile,
which a portable skill should pass everywhere.

**Is it offline?**
Completely. skillscore makes no network calls at runtime, analyzes local
files only, and is fully deterministic — the same input always produces the
same score and finding order.

**How do I score every skill in a monorepo?**
`skillscore path/to/repo/` — it walks the tree, finds every folder with a
`SKILL.md` (case-insensitive), and scores each one, deterministically
ordered by path.

**How do I score a specific set of skills in one command?**
Pass each path as a separate argument: `skillscore skill-a/ skill-b/ skill-c/`.
You get a combined report with a summary line showing the count, average, and
lowest score. Duplicate paths are silently deduplicated, so overlapping
arguments (e.g. a tree root and one of its children) each score once. If one
path is invalid, the rest still score and the bad path is reported as a warning.

**Does my skill have to be named a certain way?**
No. skillscore is name-agnostic: the frontmatter `name`, the folder name,
and the file name are all independent, and unusual names (including
non-ASCII folder names) are handled — though rule A2 will tell you if the
`name` field itself violates the official format.

**What happens with malformed frontmatter?**
No crash: the relevant A-category errors are reported and every other rule
that can still run does, so you always get a score.

## How does skillscore compare to alternatives?

- **Vendor skill validators** (e.g. quick checks built into agent CLIs)
  verify only schema validity — name format, description present. skillscore
  additionally scores *quality*: discoverability, conciseness, structure,
  instruction design, hygiene, and safety, with cited sources per rule.
- **Generic Markdown linters** (markdownlint, Vale) check prose style, not
  skill semantics; they don't know what a frontmatter `description` must
  contain for an agent to find the skill.
- **Asking an LLM to review your skill** is non-deterministic and
  unsuitable for CI gates. skillscore is static, reproducible, and exits
  with codes designed for pipelines. The two combine well.

## Library use

skillscore is also a Dart library:

```dart
import 'package:skillscore/skillscore.dart';

void main() {
  final doc = SkillParser().parseFile('my-skill/SKILL.md');
  final result = Scorer(RuleRegistry()).score(doc, Target.universal);
  print('${result.score}/100 ${result.grade}');
}
```

## Contributing

New rules are one class + one registration — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the walkthrough and the project's
design principles (every rule cites its source guide, deterministic output,
offline only, name-agnostic). Use the
["Propose a new rule" issue template](.github/ISSUE_TEMPLATE/propose_a_rule.yml)
to suggest one.

## License

[Apache-2.0](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for release history.
