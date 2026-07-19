---
name: skillscore
description: Scores, lints, and validates an agent skill or SKILL.md for quality, 0-100 with fixes, using the offline skillscore CLI. Use when asked to check, review, grade, or improve a skill's SKILL.md. Do not use for prose or non-skill Markdown.
license: Apache-2.0
allowed-tools: Bash(skillscore:*), Bash(npx:*), Read
---

# skillscore

Grade an agent skill against the official Claude, Codex, and Antigravity
authoring guides, then report the score and the fixes. This skill runs the real
`skillscore` CLI, so every result is deterministic and offline. It never grades
from memory.

## When to use

Use this when the user wants to check, review, grade, audit, or improve a
`SKILL.md` file or a folder of skills. Do not use it for ordinary prose, README
files, or any Markdown that is not an agent skill manifest.

## Workflow

1. Locate the target `SKILL.md`, or the folder that contains one.
2. Run `skillscore path/to/skill/ --format json` against that path.
3. Read each skill's `score`, `grade`, `tokens`, and `findings` from the JSON.
4. Explain any rule the user asks about with `skillscore explain <rule-id>`.
5. Apply the fixes, re-run skillscore to validate the score improved, and repeat until it stops rising.

If `skillscore` is not on `PATH`, use `npx skillscore@latest` in place of
`skillscore` in every command above. For the mechanical fixes the tool can make
itself, run `skillscore path/to/skill/ --fix`.

## Example

```bash
# Score a skill and read the machine-readable result
skillscore path/to/skill/ --format json

# Explain one finding, then let the tool fix what it safely can
skillscore explain B2_description_when
skillscore path/to/skill/ --fix
```

## Reading the result

- `score` is 0-100 and `grade` is A-F. Lead with these two numbers.
- `findings` each carry a `ruleId`, a `severity`, a `message`, and often a
  `line`. Group them by severity: error, then warning, then info.
- The `tokens` block shows the description and full-manifest token cost. A large
  description is expensive because it loads on every prompt.
- Cross-skill checks: `skillscore conflicts path/to/skills/` finds skills that
  trigger on the same requests, and `skillscore budget path/to/skills/` measures
  the always-on token cost of the whole set.

## Anti-patterns

- Do not hand-grade a skill against remembered rules. Always run the binary so
  the score is the tool's, not a guess.
- Do not paraphrase findings away. Report the `ruleId` so the user can look it
  up with `skillscore explain`.
- Do not edit a `SKILL.md` without re-running skillscore afterward. An unverified
  fix can lower the score.

## Safety

This skill only ever runs the read-only `skillscore` CLI, or `npx skillscore`,
which analyzes files locally and makes no network calls. The single exception is
`skillscore --fix`, which rewrites the target `SKILL.md` in place with safe,
mechanical corrections; run it only when the user wants automatic fixes. Do not
run any other command from this skill.

See [references/rules.md](references/rules.md) for the full rubric and the rule
ids you can pass to `skillscore explain`.
