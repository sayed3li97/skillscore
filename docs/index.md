# skillscore

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/cover.png" alt="skillscore — score your AI agent's SKILL.md 0 to 100 against the Claude, Codex, and Antigravity authoring guides" width="100%">
</p>

**Lint and score any AI agent skill (SKILL.md) against the official Claude,
Codex, and Antigravity authoring guides.**

Available as an **offline Dart CLI** for terminals and CI, and as a
**VS Code extension** for inline scoring inside your editor.

| | Install |
|---|---|
| **CLI** | `dart pub global activate skillscore` |
| **VS Code / Cursor / Windsurf** | [VS Marketplace](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore) |
| **Antigravity IDE / VSCodium** | [Open VSX](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore) |

skillscore reads a `SKILL.md` manifest (or a whole monorepo of them),
applies 27 rules derived from the official skill-authoring guides, and
produces a 0–100 score, a letter grade, and actionable findings with fix
hints. Offline, deterministic, and built for CI gating.

## See it in action

skillscore grading the Flutter team's own `flutter-add-widget-test` skill
(90/A), then explaining a finding with its source guide:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/skillscore-demo.gif" alt="Terminal recording: skillscore scores the Flutter team's flutter-add-widget-test skill 90 out of 100 grade A, then skillscore explain shows the rule rationale and its Flutter authoring-guide source" width="90%">
</p>

Multi-path scoring — three skills from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) in one command, then a drill-down into the lowest scorer:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/multipath-demo.gif" alt="Terminal recording: skillscore scores three agent-skills in one command showing 91/A, 88/B, and 77/C, then drills into the 77/C skill to show the missing Safety section error and vague description warning" width="90%">
</p>

## Token budget

Every scorecard now shows the BPE token cost of each skill, split by the two
scopes in which agent runtimes load SKILL.md content:

```
  Tokens  description (permanent)    67 gpt-4   ~74 claude
          full manifest (active)   1474 gpt-4  ~1622 claude
```

**Permanent** is the per-prompt cost paid so the agent knows the skill exists.
**Active** is the per-invocation cost paid only when the skill fires.

Tested on all 31 skills from [google/skills](https://github.com/google/skills).
Description tokens ranged from 24 to 142 — a 6x spread. The 56/F `gke-basics`
skill pays 142 tokens on every prompt for discovery; the 95/A
`agent-platform-tuning-management` pays 67. Better skill, lower cost.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/token-demo.gif" alt="Terminal recording: skillscore scans 31 Google skills showing scores and token counts, then drills into the top scorer (95/A, 67-token description) and the lowest (56/F, 142-token description)" width="90%">
</p>

Counts use cl100k_base BPE (exact for GPT-4/Codex; Claude adds a 10% estimate).
Token counts appear in `--format json` under a `tokens` key for CI and dashboards.

### API-validated accuracy

The +10% estimate was validated against the official Anthropic `count_tokens` API
across all 31 Google skills: mean actual overhead +10.2%, median exactly +10.0%,
range +0% to +20% (keyword-dense descriptions run higher; clean prose runs lower).

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/validate-demo.gif" alt="Terminal recording: Anthropic count_tokens API validation across all 31 Google skills showing mean overhead of +10.2% and median of +10.0%" width="90%">
</p>

---

## Editor extension

Score SKILL.md files without leaving your editor. The extension adds inline
squiggly underlines on every failing rule, a hover tooltip with the fix hint
and rule ID, a sidebar panel with per-category scores and progress bars, and
a live status-bar indicator.

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/skillscore-plugin-demo.gif" alt="VS Code / Antigravity IDE extension showing inline diagnostics, hover tooltip, and Skillscore sidebar panel scoring a SKILL.md file" width="90%">
</p>

Install from the [VS Marketplace](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore) (VS Code, Cursor, Windsurf) or [Open VSX](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore) (Antigravity IDE, VSCodium). Source at [skillscore-vscode](https://github.com/sayed3li97/skillscore-vscode).

---

## CLI quickstart

```bash
dart pub global activate skillscore

skillscore path/to/SKILL.md        # one skill
skillscore path/to/skills/         # every skill in a tree
skillscore skill-a/ skill-b/ skill-c/  # specific skills in one shot
skillscore my-skill/ --target claude
skillscore my-skill/ --format json
skillscore skills/ --min-score 80  # CI gate
```

## How the score works

100 points across six categories: frontmatter validity (15), description
quality (25), conciseness (15), structure (15), instruction quality (20),
hygiene (10); plus a safety penalty (up to -15) when a skill ships scripts
without documenting them. Grades: A 90+, B 80+, C 70+, D 60+, F below.

The [full rubric with every rule, weight, and source citation](https://github.com/sayed3li97/skillscore#the-full-rubric)
is in the README, or run `skillscore rules`.

## FAQ

**Which agents does it cover?** Claude Code, Codex, Antigravity, Gemini
CLI, and Cursor all share the SKILL.md format; score against one vendor's
rules with `--target` or use the portable `universal` default.

**Is it offline?** Yes. No network calls, local files only, deterministic output.

**Where do the rules come from?** Every rule cites the official guide it
derives from (Anthropic, Antigravity, Codex, or Flutter's official skills
practice); `skillscore explain <rule-id>` prints the citation.

## Links

- [CLI GitHub repository](https://github.com/sayed3li97/skillscore)
- [pub.dev package](https://pub.dev/packages/skillscore)
- [VS Code extension](https://github.com/sayed3li97/skillscore-vscode)
- [VS Marketplace listing](https://marketplace.visualstudio.com/items?itemName=sayed-ali-alkamel.skillscore)
- [Open VSX listing](https://open-vsx.org/extension/sayed-ali-alkamel/skillscore)
- [google/skills](https://github.com/google/skills) — official Google Cloud skill library used in the token-budget demo
- [Contributing guide](https://github.com/sayed3li97/skillscore/blob/main/CONTRIBUTING.md)
