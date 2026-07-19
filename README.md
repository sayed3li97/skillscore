# skillscore

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/cover.png" alt="skillscore cover: score your agent's SKILL.md 0 to 100. A radial rubric ring shows a perfect score of 100, grade A, formed by six weighted category segments, in a dark monospace blue-accent theme" width="100%">
</p>

[![CI](https://github.com/sayed3li97/skillscore/actions/workflows/ci.yml/badge.svg)](https://github.com/sayed3li97/skillscore/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/skillscore.svg)](https://pub.dev/packages/skillscore)
[![VS Marketplace](https://img.shields.io/visual-studio-marketplace/v/sayed-ali-alkamel.skillscore?label=VS%20Marketplace&color=blue)](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore)
[![Open VSX](https://img.shields.io/open-vsx/v/sayed-ali-alkamel/skillscore?label=Open%20VSX&color=purple)](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore)
[![license: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**skillscore** statically analyzes any AI agent skill (a `SKILL.md` manifest and its folder) and produces a **0 to 100 quality score**, a **letter grade**, and a list of **actionable findings**, scored against the official skill-authoring guides from **Anthropic (Claude)**, **Google (Antigravity)**, and **OpenAI (Codex)**. It is offline, deterministic, and built for CI.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/shots/score.png" alt="Terminal: skillscore scores a skill 100 out of 100 grade A, with token budget, per-category bars A through G, and no findings" width="88%">
</p>

## What is skillscore?

skillscore is a **skill linter, `SKILL.md` validator, and agent-skill quality checker**. Agent skills are an open standard: a folder with a `SKILL.md` (YAML frontmatter plus a Markdown body) and optional `references/`, `examples/`, `scripts/`, and `assets/` subfolders, used by Claude Code, Codex, Antigravity, Gemini CLI, and Cursor.

Because an agent keeps every skill's `name` and `description` in its context budget permanently, **a vague or malformed skill is worse than no skill**. skillscore catches exactly those problems before a skill ships, and it never leaves your machine.

## How it works

A manifest goes in, a score comes out. Every step runs locally.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/diagrams/pipeline.svg" alt="Pipeline diagram: SKILL.md to Parser to a Rule engine of 26 rules across 7 categories to the Scorer that normalizes to 0-100 to a Scorecard, with a note that every step is on-device and skillscore never touches the network" width="100%">
</p>

The parser reads the frontmatter and body, the rule engine runs 26 checks grouped into 7 categories, and the scorer normalizes the result to a 0 to 100 score with a letter grade. There is no network call anywhere in that path.

## Quickstart

```bash
# Install
dart pub global activate skillscore

# Score a single skill (any name, any location)
skillscore path/to/SKILL.md

# Score every skill in a folder or monorepo
skillscore path/to/skills/

# Score several specific skills in one command
skillscore skill-a/ skill-b/ skill-c/

# Pick a target ruleset
skillscore my-skill/ --target claude

# Machine-readable output for CI and dashboards
skillscore my-skill/ --format json

# Gate CI: fail the build if any skill scores below 80
skillscore skills/ --min-score 80
```

## Scoring, and the rubric

100 points, seven categories, each rule tagged with the authoring guide it comes from.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/diagrams/rubric.svg" alt="Rubric diagram: horizontal weight bars for Frontmatter validity 17 points, Description quality 28, Conciseness and token economy 15, Structure and progressive disclosure 15, Instruction quality 20, Content hygiene 10, and a Safety and scripts penalty up to minus 15, normalized to 0-100" width="100%">
</p>

Each rule awards full, partial, or zero points. Category G (safety) is a **penalty** of up to `-15` that applies only when a skill ships scripts or terminal commands. Profiles that exclude a rule (for example `--target claude` excludes the Codex-specific B4) are normalized back to a 0 to 100 scale, so scores stay comparable across targets.

**Grades:** A is 90 and up, B is 80 and up, C is 70 and up, D is 60 and up, F is below 60.

<details>
<summary><b>The full rubric (all 26 rules)</b></summary>

| Rule | Title | Pts | Severity | Targets | Source |
|---|---|---|---|---|---|
| `A1_frontmatter_present` | YAML frontmatter delimited by `---` | 4 | error | all | Anthropic |
| `A2_name_format` | `name` at most 64 chars, lowercase / digits / hyphens | 4 | error | all | Anthropic |
| `A3_name_reserved_words` | `name` avoids "anthropic" and "claude" | 3 | error (claude) / info | all | Anthropic |
| `A4_description_present` | `description` present, at most 1024 chars | 4 | error | all | Anthropic |
| `A5_frontmatter_keys` | Only recognized keys, no typos ("did you mean") | 2 | warning | all | Anthropic |
| `B1_description_what` | States WHAT (opens with an action verb) | 6 | warning | all | Anthropic |
| `B2_description_when` | States WHEN ("use when ...") | 6 | warning | all | Anthropic |
| `B3_third_person` | Written in third person | 5 | warning | all | Anthropic |
| `B4_frontloaded_triggers` | Concrete keywords in the first 60 chars | 4 | warning | codex, universal | Codex |
| `B5_boundary_clause` | Has a "do not use" boundary | 4 | warning (antigravity) / info | antigravity, universal | Antigravity |
| `B6_description_truncation` | Self-contained within 250 chars (Claude routing) | 3 | warning | claude, universal | Anthropic |
| `C1_body_length` | Body at most 500 lines (linear to 0 at 1000) | 6 | warning | all | Anthropic |
| `C2_explainer_bloat` | No definitions of common knowledge | 5 | warning | all | Anthropic |
| `C3_excessive_optionality` | No long "or" chains | 4 | info | all | Anthropic |
| `D1_progressive_disclosure` | Depth split into references / examples | 5 | info | all | Anthropic |
| `D2_one_level_links` | Reference links one level deep | 5 | warning | all | Anthropic |
| `D3_reference_toc` | Long reference files have a TOC | 5 | info | all | Anthropic |
| `E1_anti_patterns` | States anti-patterns explicitly | 6 | warning | all | Flutter |
| `E2_workflow_checklist` | Checklist or numbered workflow | 5 | warning | all | Anthropic |
| `E3_feedback_loop` | Validate, fix, repeat loop | 5 | warning | all | Anthropic |
| `E4_code_example` | At least one fenced code example | 4 | warning | all | Anthropic |
| `F1_time_sensitive` | No date-anchored statements that rot | 4 | warning | all | Anthropic |
| `F2_forward_slashes` | Paths use forward slashes only | 3 | error | all | Anthropic |
| `F3_consistent_terminology` | No synonym mixing (conservative) | 3 | info | all | Anthropic |
| `G1_safety_section` | Scripts / commands need a Safety section | -8 | error | antigravity, universal | Antigravity |
| `G2_script_docs` | Bundled scripts are documented | -7 | warning | all | Anthropic |

Run `skillscore rules` for the live table, or `skillscore explain <rule-id>` for any rule's rationale, fix, and source.

</details>

Every finding cites the guide it comes from, and `skillscore explain` prints the rationale and the fix:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/shots/explain.png" alt="Terminal: skillscore explain B2_description_when shows the title, category, points, severity, targets, source guide, why the rule exists, and how to fix it" width="88%">
</p>

## One manifest, four guides

The same `SKILL.md` can be scored through four different authoring guides. Pick a lens with `--target`; the default `universal` is the union of all of them.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/diagrams/targets.svg" alt="Targets diagram: one SKILL.md fans out to four target profiles: claude (Anthropic, adds B6), antigravity (Google, adds B5 and G1), codex (OpenAI, adds B4), and universal (every guide, portable, the default)" width="100%">
</p>

A skill that passes `universal` is portable across all four runtimes, because `universal` activates every guide's rules at once. Each rule stays tagged with its origin, so a finding always tells you which guide it comes from.

## Scoring a whole monorepo

Pass a folder or several paths and skillscore walks the tree, finds every `SKILL.md` (case-insensitive), scores each one, and prints a summary. Overlapping paths are deduplicated; if one path is bad, the rest still score and the bad one is reported as a warning.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/shots/multipath.png" alt="Terminal: skillscore scores three skills in one command, showing csv-to-xlsx 73 grade C, legacy-notes 7 grade F, pdf-form-filler 100 grade A, and a summary line with the count, average, and lowest score" width="88%">
</p>

## Token budget

Every scorecard shows the BPE token cost of a skill, split by the two scopes in which agent runtimes load `SKILL.md` content:

```text
  Tokens  description (permanent)    67 gpt-4   ~74 claude
          full manifest (active)   1474 gpt-4  ~1622 claude
```

**Permanent** is the per-prompt cost: the agent loads the `description` field on every call so it knows which skills exist. **Active** is the per-invocation cost, paid only when the agent decides to use the skill.

Counts use the **cl100k_base** BPE vocabulary (exact for GPT-4 and Codex). The Claude estimate adds a calibrated 10% overhead, and it appears in `--format json` under a `tokens` key for dashboards and CI.

<details>
<summary><b>Validated against the Anthropic count_tokens API</b></summary>

The 10% Claude estimate was checked against the official Anthropic `count_tokens` API across all 31 skills in [google/skills](https://github.com/google/skills):

| Metric | Value |
|---|---|
| Skills validated | 31 (all of google/skills) |
| Mean actual Claude overhead vs cl100k | +10.2% |
| Median | +10.0% |
| Range | +0% to +20% (varies with keyword density) |

Descriptions dense with trigger keywords run toward +18 to +20%; clean prose runs toward 0 to 6%.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/token-demo.gif" alt="Terminal recording: skillscore scans all 31 Google skills, then drills into the top and lowest scorers, showing token counts alongside each scorecard" width="80%">
</p>

</details>

## Catching frontmatter typos (rule A5)

The `SKILL.md` frontmatter is a fixed set of keys (`name`, `description`, `license`, `allowed-tools`, `metadata`, `version`), and YAML gives you no protection when you misspell one. Write `descrption:` and YAML happily accepts it as an unknown field while the real `description` goes *missing*. The skill still loads, but with empty metadata it is invocable only by name and is **never auto-triggered**. Strict validators, including Anthropic's own `skill-creator`, reject any unexpected key outright.

Rule **`A5_frontmatter_keys`** catches this. It flags every top-level key outside the recognized set, and when the key is a near-miss for a real one (within an edit distance of two) it tells you which key you meant:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/qa/a5/evidence/A5-02.png" alt="skillscore scoring a skill whose description key is misspelled as descrption: an A4 error reports the missing description and an A5 warning says Unknown frontmatter key descrption, did you mean description?" width="82%">
</p>

The two findings together tell the whole story: `A4` reports the field is gone, and `A5` points at the typo that swallowed it. Design details:

- **Custom fields are welcome, under `metadata`.** Only top-level keys are checked, so anything nested inside a `metadata:` map is yours to name freely and is never flagged.
- **No false suggestions.** A genuinely unrecognized key such as `author` is flagged without a misleading "did you mean", because it is not close to any real key. (Move it under `metadata`.)
- **No double-counting.** When the frontmatter is missing or malformed entirely, `A5` stays silent and lets `A1` own that failure.
- **Fully offline and deterministic.** The "did you mean" suggestion is a local Levenshtein comparison. No network, no model.

A full QA record for this rule, every case run against the compiled binary with screenshot evidence, lives in [`docs/qa/a5/`](docs/qa/a5/REPORT.md).

### Fix it automatically with `--fix`

When a finding has a safe, mechanical correction, skillscore marks it `[fixable]` and can apply it in place. A misspelled key is the first such fix: `skillscore <path> --fix` renames `descrption:` to `description:`, then re-scores so the report and the exit code reflect the corrected file.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/shots/fix.png" alt="Before and after: skillscore my-skill/ reports 68 out of 100 grade D with an A4 error and an A5 fixable warning about a misspelled descrption key; then skillscore my-skill/ --fix renames it to description and the skill re-scores 100 out of 100 grade A with no findings" width="82%">
</p>

One typo drops the skill to a D (the real `description` is missing, so the description rules all fail); `--fix` recovers it to a perfect A. The fix is deterministic and idempotent, preserves your line endings, and only ever touches a key that has a confident "did you mean" match. Keys with no near match (move them under `metadata` yourself) are left untouched, never guessed at.

## Eval harness

Static linting tells you a skill is well-formed. The eval harness tells you **whether queries actually route to it**, the thing that matters once a skill is deployed. Three commands, one workflow, no API key.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/diagrams/eval.svg" alt="Eval harness diagram: eval init scaffolds 20 queries (10 should-trigger, 10 should-not), eval validate checks balance and thresholds, eval run scores 3 runs per query and passes if the trigger-rate is at least 0.5, all offline with no API key" width="100%">
</p>

```bash
# 1. Scaffold 20 queries from the skill's description
skillscore eval init my-skill/

# 2. Review and extend the generated queries
cat my-skill/evals.json

# 3. Run the eval, fully offline, no API key, no cost
skillscore eval run my-skill/
```

`eval init` reads the `description` and derives 20 queries: 10 that should trigger the skill and 10 that should not. `eval validate` checks the suite has both classes and sane thresholds. `eval run` scores each query 3 times and passes it when the trigger-rate clears (or, for non-trigger queries, stays under) the 0.5 threshold.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/shots/eval.png" alt="Terminal: skillscore eval run shows runs per query, threshold, query counts, a PASS table for trigger and non-trigger queries, and a final 20 passed 0 failed" width="88%">
</p>

<details>
<summary><b>How the offline scoring heuristic works</b></summary>

`eval run` uses a **local heuristic**, no model call and no network. It scores each query by matching content words against three regions pulled from the `description`:

| Region | Source | Role |
|---|---|---|
| **Trigger terms** | the "Use when ..." clause, scaffold words stripped | what activates the skill |
| **Boundary terms** | the "Do not use ..." clause | what the skill excludes |
| **What terms** | the first sentence of the description | the skill's primary capability |

All text is lowercased, tokenized, stop-word filtered, and suffix-stemmed before comparison.

**Boundary exclusivity.** A boundary term penalizes a query only when it does not also appear in the trigger or what regions. This stops a shared noun (for example `pdf` in "Do not use for scanned PDFs") from falsely blocking a trigger query that legitimately mentions the same noun.

**Wave noise.** A small deterministic offset cycles through roughly plus or minus 7% across successive calls, so a borderline query may trigger on two runs of three and not the other, modeling the natural variance of a real model.

**What PASS and FAIL mean.** A trigger query passes when its triggered count is at least `trigger_threshold x runs_per_query` (default 2 of 3); a non-trigger query passes when it stays below that. The heuristic measures textual alignment with the skill's declared intent, not live model routing, so use it to catch obvious description problems early.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/eval-algo.png" alt="Flowchart of the heuristic scoring algorithm: meta-query check, clause term extraction, boundary exclusivity filter, content-word match count, wave noise, and the final threshold comparison" width="58%">
</p>

</details>

## Find overlapping skills with `conflicts`

An agent picks which skill to load by matching a request against every skill's
`description`. So the moment two skills describe themselves with the same words,
they compete for the same requests and the agent loads the wrong one, silently.
It is the most common reason a skill "does not trigger," and no other linter
looks for it.

`skillscore conflicts` does. It compares the **trigger surface** (the `use when`
clause plus the opening sentence) of every pair of skills in a folder and flags
the pairs that overlap, with the exact shared words:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/shots/conflicts.png" alt="Terminal: skillscore conflicts skills/ finds one overlapping pair across 4 skills, pdf-form-filler and pdf-populate at 75 percent overlap, with shared triggers data, field, fill, form, pdf, populate, and a fix hint to add a do-not-use boundary" width="88%">
</p>

```bash
skillscore conflicts skills/                      # report (advisory, exits 0)
skillscore conflicts skills/ --max-overlap 0.6    # CI gate: exit 1 on a pair >= 0.6
skillscore conflicts skills/ --format json        # machine-readable pairs
```

The fix it points you at is the one the authoring guides recommend: give each
skill a specific, non-overlapping trigger and an explicit "do not use for ..."
boundary so the agent can tell them apart. It is fully offline and
deterministic, and reuses the same term extraction as the eval harness.

## Output formats and CI

Three renderers, one flag. `pretty` (the default) is the colored scorecard; `json` is a stable machine shape for dashboards; `sarif` is a valid SARIF 2.1.0 document that GitHub code scanning renders as inline PR annotations.

```yaml
# .github/workflows/skills.yml
- name: Lint agent skills
  run: |
    dart pub global activate skillscore
    skillscore skills/ --min-score 80 --no-color
```

`--min-score` fails the build when any skill scores below the threshold, `--strict` promotes warnings to failures, and the exit codes are designed for pipelines: `0` all good, `1` a quality gate failed, `2` a usage error.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/diagrams/cicd.svg" alt="CI/CD diagram: git push to a CI runner that activates skillscore, which runs the --min-score gate, branching to merge on exit 0, code scanning via SARIF, and block on exit 1" width="100%">
</p>

The same three steps drop into any runner. The **[CI/CD guide](docs/ci/README.md)** has copy-paste configs for ten platforms (GitHub Actions, GitLab CI, CircleCI, Jenkins, Azure Pipelines, Bitbucket, Travis, Drone, Google Cloud Build, and pre-commit), a reusable GitHub Action (`uses: sayed3li97/skillscore@v1`), a pre-commit hook, and a container image, with a real GitHub Actions run and its SARIF findings in the Security tab.

## Commands and flags

```text
skillscore <path> [<path> ...]     Score one or more manifests, folders, or trees
skillscore rules                   List every rule: id, points, severity, targets, source
skillscore explain <rule-id>       Print a rule's rationale, the fix, and its source guide
skillscore eval init <path>        Scaffold evals.json from the skill's description
skillscore eval validate <path>    Validate and summarize evals.json
skillscore eval run <path>         Run trigger-rate evals offline (no API key)
skillscore conflicts <path> ...    Find skills that trigger on the same requests
skillscore --version
skillscore --help
```

| Flag | Values | Default | Purpose |
|---|---|---|---|
| `--target` | `claude` \| `antigravity` \| `codex` \| `universal` | `universal` | Which guide's ruleset to apply |
| `--format` | `pretty` \| `json` \| `sarif` | `pretty` | Output format (SARIF renders in code-review tools) |
| `--min-score <n>` | 0 to 100 | unset | Exit non-zero if any skill scores below `n` |
| `--baseline <file>` | path | unset | Gate on new findings only; tolerate the recorded backlog. Created if missing |
| `--update-baseline` | flag | off | Rewrite the `--baseline` file from the current findings |
| `--fix` | flag | off | Apply safe auto-fixes in place (rename a misspelled key), then re-score |
| `--strict` | flag | off | Treat warning-level findings as failures |
| `--quiet` | flag | off | Print only the score line per skill |
| `--no-color` | flag | off | Disable ANSI colors |

**Exit codes:** `0` every skill met the gate. `1` a skill is below `--min-score`, or `--strict` found an error or warning, or an eval run failed. `2` a usage error (bad path, unreadable file, unknown rule, invalid flag).

### Adopt the gate on an existing fleet with `--baseline`

Turning a strict gate on a repo that already has dozens of skills is all-or-nothing without a way to grandfather the current state. `--baseline` is that way (the same idea as ESLint bulk suppressions and Ruff's baseline):

```bash
# Once: record today's findings as the accepted backlog (exits 0)
skillscore skills/ --baseline .skillscore-baseline.json

# In CI: fail only when a NEW finding appears, backlog tolerated
skillscore skills/ --baseline .skillscore-baseline.json
```

Findings are fingerprinted by `(path, rule)`, so fixing an unrelated line never invalidates the baseline. Commit the file, and from that point the build fails on regressions while the backlog is burned down at your own pace. `--update-baseline` re-accepts the current state after you have intentionally taken on new findings. The score itself is never changed; pair it with `--min-score` if you also want a score floor.

## Editor integration

Prefer to score inside your IDE? The **[Skillscore VS Code extension](https://github.com/sayed3li97/skillscore-vscode)** wraps this CLI and adds inline diagnostics, hover tooltips with the fix and rule id, a sidebar score panel, and a live status-bar indicator. It works in VS Code, Antigravity IDE, VSCodium, and Cursor.

Install from the [VS Marketplace](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore) or [Open VSX](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore).

## Use it inside Claude Code — a skill that scores skills

skillscore ships as an installable agent skill of its own, in [`skill/skillscore/`](skill/skillscore/SKILL.md). Drop it into your agent's skills folder (for Claude Code, `~/.claude/skills/`) and the agent can score the `SKILL.md` it just wrote, in-loop, before saving it:

```bash
cp -r skill/skillscore ~/.claude/skills/skillscore
# then, in Claude Code: "score this skill" / "check my SKILL.md"
```

It shells out to the real CLI (via `skillscore` or `npx skillscore`), so the grade is the tool's deterministic score, not a guess from memory. Fittingly, the skill scores **100/100** against skillscore itself — CI enforces it on every push.

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

## FAQ

**What is an agent skill?**
A folder with a `SKILL.md` manifest (YAML frontmatter plus Markdown instructions) that teaches an AI agent a repeatable task. Optional subfolders hold references, examples, scripts, and assets.

**Does it work with Claude Code, Codex, Antigravity, Gemini CLI, and Cursor?**
Yes. They share the `SKILL.md` format. Score against one vendor's rules with `--target`, or use the default `universal` profile that a portable skill should pass everywhere.

**Is it offline?**
Completely. Both the linter and the eval harness read local files only and make no network calls. Output is deterministic given the same input.

**Does my skill have to be named a certain way?**
No. skillscore is name-agnostic: the frontmatter `name`, the folder name, and the file name are independent. Unusual and non-ASCII folder names are handled, though rule A2 will tell you if the `name` field itself breaks the official format.

**What happens with malformed frontmatter?**
No crash. The relevant A-category errors are reported and every other rule that can still run does, so you always get a score.

## How does skillscore compare?

- **Vendor skill validators** verify only schema validity (name format, description present). skillscore additionally scores *quality*: discoverability, conciseness, structure, instruction design, hygiene, and safety, with a cited source per rule.
- **Generic Markdown linters** (markdownlint, Vale) check prose style, not skill semantics. They do not know what a frontmatter `description` needs for an agent to find the skill.
- **Asking an LLM to review a skill** is non-deterministic and unsuitable for a CI gate. skillscore is static, reproducible, and exits with pipeline-friendly codes. The two combine well.

## Contributing

A new rule is one class plus one registration. See [CONTRIBUTING.md](CONTRIBUTING.md) for the walkthrough and the project's design principles: every rule cites its source guide, output is deterministic, everything is offline, and nothing assumes a skill's name. Use the ["Propose a new rule" issue template](.github/ISSUE_TEMPLATE/propose_a_rule.yml) to suggest one.

## License

[Apache-2.0](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for release history.
