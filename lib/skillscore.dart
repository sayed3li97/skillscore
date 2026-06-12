// SPDX-License-Identifier: Apache-2.0

/// Lint and score AI agent skills (SKILL.md) against the official
/// Claude, Codex, and Antigravity authoring guides.
///
/// The library behind the `skillscore` CLI. Typical use:
///
/// ```dart
/// final parser = SkillParser();
/// final doc = parser.parseFile('my-skill/SKILL.md');
/// final result = Scorer(RuleRegistry()).score(doc, Target.universal);
/// print('${result.score}/100 ${result.grade}');
/// ```
library;

export 'src/cli/cli_runner.dart' show exitFailedGate, exitOk, exitUsage, runCli;
export 'src/model/finding.dart';
export 'src/model/skill_document.dart';
export 'src/parsing/skill_parser.dart';
export 'src/reporting/json_reporter.dart';
export 'src/reporting/pretty_reporter.dart';
export 'src/reporting/sarif_reporter.dart';
export 'src/rules/conciseness_rules.dart';
export 'src/rules/description_rules.dart';
export 'src/rules/frontmatter_rules.dart';
export 'src/rules/hygiene_rules.dart';
export 'src/rules/instruction_rules.dart';
export 'src/rules/registry.dart';
export 'src/rules/rule.dart';
export 'src/rules/safety_rules.dart';
export 'src/rules/structure_rules.dart';
export 'src/scoring/scorer.dart';
export 'src/version.dart';
