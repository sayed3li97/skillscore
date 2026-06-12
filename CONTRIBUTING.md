# Contributing to skillscore

Thanks for helping make agent skills better. This guide explains the
architecture, the design principles, and the end-to-end walkthrough for
adding a rule.

## Design principles

1. **Every rule cites its source.** A rule must derive from an official
   authoring guide (Anthropic, Antigravity, Codex, or the official Flutter
   skills practice) and name it in `sourceGuide`, in its doc comment, and in
   the README rubric table.
2. **Deterministic output.** The same input always produces the same score
   and the same finding order. No randomness, no clock reads, no
   environment-dependent behavior.
3. **Offline only.** The tool never makes network calls at runtime.
4. **Name-agnostic.** Nothing may assume a particular skill name, folder
   name, or manifest file name.
5. **Conservative heuristics.** A false positive erodes trust faster than a
   false negative; when a textual heuristic is uncertain, prefer not
   flagging (see `F3_consistent_terminology` for the pattern).

## Project layout

```
bin/skillscore.dart              CLI entrypoint
lib/src/model/                   SkillDocument, Finding, Severity, Target
lib/src/parsing/skill_parser.dart  discovery + frontmatter/body parsing
lib/src/rules/                   one file per rubric category + registry
lib/src/scoring/scorer.dart      weighting, normalization, penalty cap, grade
lib/src/reporting/               pretty / json / sarif reporters
test/                            one test file per category + scorer/reporters/CLI/robustness
test/fixtures/                   end-to-end fixtures (excellent / mediocre / broken / robustness)
```

## Adding a new rule, end to end

1. **Implement one class** in the appropriate `lib/src/rules/*_rules.dart`
   file (or a new file for a new category), extending `BaseRule`:

   ```dart
   /// H1: <what it checks>. Source: <guide>.
   class MyNewRule extends BaseRule {
     @override
     String get id => 'H1_my_new_rule';
     @override
     String get title => 'One-line title';
     @override
     String get sourceGuide => 'Anthropic';
     @override
     int get maxPoints => 5; // negative for penalty rules
     @override
     Set<Target> get targets => Target.values.toSet();
     @override
     Severity get defaultSeverity => Severity.warning;
     @override
     String get rationale => 'Why the guide requires this.';
     @override
     String get fixHint => 'How to fix a violation.';

     @override
     RuleResult evaluate(SkillDocument doc, Target target) {
       // Use doc.body, doc.proseLines, doc.frontmatter, doc.references, ...
       // Report line numbers via doc.bodyLineNumber(index).
       return pass(); // or fail([finding('...', line: n)]);
     }
   }
   ```

2. **Register it** in `RuleRegistry._builtinRules` (in rubric order). If the
   severity differs per target, add entries to
   `RuleRegistry.severityOverrides` — target behavior is data, never
   scattered conditionals.
3. **Add fixtures and tests**: at least one passing and one failing case in
   `test/rules/<category>_rules_test.dart`. If the rule is gradeable,
   document the partial-credit formula in a doc comment on `evaluate` and
   test it.
4. **Document it** in the README rubric table (it must match the
   implementation exactly) and run the suite:

   ```bash
   dart analyze && dart format . && dart test
   ```

That's it — scoring, normalization, `skillscore rules`, `skillscore
explain`, and all three reporters pick the rule up automatically from the
registry.

Note: if your rule adds positive points to the `universal` profile, the
profile no longer totals 100 raw points; the scorer normalizes
automatically, but keep the README's "How is the score calculated?" section
honest about the weights.

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/):
`feat: add H1 rule`, `fix: handle CRLF in parser`, `docs: ...`,
`test: ...`, `chore: ...`.

## Ambiguity decisions made during the initial build

Recorded here so future contributors know they were deliberate:

- **Per-target normalization.** Profiles that exclude rules (claude: −B4
  −B5; codex: −B5; antigravity: −B4) are normalized to a 0–100 scale so
  grades stay comparable: `score = awarded / achievable × 100 + penalty`.
- **Dependent rules award 0 silently.** When `description` is missing, the
  B rules award 0 points without findings (A4 already reports the cause).
  Same for A3 when `name` is missing.
- **A3 active on all targets** with severity ERROR only on `claude` (the
  spec's "for other targets this is INFO only"), via `severityOverrides`.
- **Universal takes the most lenient severity** where guides differ (A3 →
  info, B5 → info); G1 keeps its specified ERROR default on the targets
  where it is active.
- **Partial-credit formulas**: C1 `6×(1000−lines)/500` clamped; C2
  `5−2.5×flaggedLines`; C3 `4−2×flaggedLines`; D2 `5−2.5×chains`; D3
  `5×compliant/longFiles` — each documented on the rule's `evaluate`.
- **G applicability** is `scripts/` files present, `scripts/` referenced in
  the body, a `bash`/`sh`/`shell`/`zsh`/`powershell`/`console` fence, or
  `$ `-prefixed command lines.
- **Symlink policy**: directory walks never follow symlinks
  (`followLinks: false`), which guarantees a scan cannot escape the tree.
- **Unit tests construct manifests inline** via `parseContent`/temp dirs
  for precision; the committed `test/fixtures/` cover end-to-end and
  robustness behavior. Per-rule pass/fail coverage lives in
  `test/rules/<category>_rules_test.dart`.
- **F2 scans prose lines only** (code fences excluded) to avoid flagging
  escape sequences like `\n` in code examples as backslash paths.

## Code of conduct

This project follows the [Contributor Covenant v2.1](CODE_OF_CONDUCT.md).
