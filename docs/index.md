# skillscore

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/cover.png" alt="skillscore — score your AI agent's SKILL.md 0 to 100 against the Claude, Codex, and Antigravity authoring guides" width="100%">
</p>

**Lint and score any AI agent skill (SKILL.md) against the official Claude,
Codex, and Antigravity authoring guides — offline Dart CLI.**

skillscore reads a `SKILL.md` manifest (or a whole monorepo of them),
applies 24 rules derived from the official skill-authoring guides, and
prints a 0–100 score, a letter grade, and actionable findings with fix
hints. It is offline, deterministic, and built for CI gating.

## See it in action

skillscore grading the Flutter team's own `flutter-add-widget-test` skill
(90/A), then explaining a finding with its source guide:

<p align="center">
  <img src="https://raw.githubusercontent.com/sayed3li97/skillscore/main/docs/assets/skillscore-demo.gif" alt="Terminal recording: skillscore scores the Flutter team's flutter-add-widget-test skill 90 out of 100 grade A, then skillscore explain shows the rule rationale and its Flutter authoring-guide source" width="90%">
</p>

## Quickstart

```bash
dart pub global activate skillscore

skillscore path/to/SKILL.md        # one skill
skillscore path/to/skills/         # every skill in a tree
skillscore my-skill/ --target claude
skillscore my-skill/ --format json
skillscore skills/ --min-score 80  # CI gate
```

## How the score works

100 points across six categories — frontmatter validity (15), description
quality (25), conciseness (15), structure (15), instruction quality (20),
hygiene (10) — plus a safety penalty (up to −15) when a skill ships scripts
without documenting them. Grades: A 90+, B 80+, C 70+, D 60+, F below.

The [full rubric with every rule, weight, and source citation](https://github.com/sayed3li97/skillscore#the-full-rubric)
is in the README, or run `skillscore rules`.

## FAQ

**Which agents does it cover?** Claude Code, Codex, Antigravity, Gemini
CLI, and Cursor all share the SKILL.md format; score against one vendor's
rules with `--target` or use the portable `universal` default.

**Is it offline?** Yes — no network calls, local files only, deterministic
output.

**Where do the rules come from?** Every rule cites the official guide it
derives from (Anthropic, Antigravity, Codex, or Flutter's official skills
practice); `skillscore explain <rule-id>` prints the citation.

## Links

- [GitHub repository](https://github.com/sayed3li97/skillscore)
- [pub.dev package](https://pub.dev/packages/skillscore)
- [Contributing guide](https://github.com/sayed3li97/skillscore/blob/main/CONTRIBUTING.md)
