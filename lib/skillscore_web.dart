// SPDX-License-Identifier: Apache-2.0

/// The web-safe subset of skillscore: the scorer, rules, token counter, and
/// cross-skill analyses, with **no `dart:io`**, so it compiles to JS/Wasm for
/// the browser playground.
///
/// Parse a manifest with [parseSkillContent] (side files default to empty),
/// then score it:
///
/// ```dart
/// final doc = parseSkillContent(text, manifestPath: 'SKILL.md');
/// final result = Scorer(RuleRegistry(), tokenCounter: TokenCounter())
///     .score(doc, Target.universal);
/// print('${result.score}/100 ${result.grade}');
/// ```
///
/// It deliberately omits filesystem discovery (`SkillParser.parseFile`), the
/// CLI, the fixer, and the eval harness, which all need `dart:io`.
library;

export 'src/analysis/conflicts.dart';
export 'src/analysis/skill_terms.dart';
export 'src/model/finding.dart';
export 'src/model/skill_document.dart';
export 'src/parsing/skill_parser_core.dart';
export 'src/rules/registry.dart';
export 'src/rules/rule.dart';
export 'src/scoring/scorer.dart';
export 'src/tokens/token_counter.dart';
export 'src/version.dart';
