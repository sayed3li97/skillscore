// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../model/skill_document.dart';

/// The outcome of evaluating one rule against one skill.
class RuleResult {
  /// Creates a rule result.
  const RuleResult({required this.points, this.findings = const []});

  /// Points awarded: `0..maxPoints` for scoring rules, or a negative
  /// value for penalty rules (category G).
  final double points;

  /// Findings produced by the rule, with line numbers when known.
  final List<Finding> findings;
}

/// A single scoring rule derived from an official authoring guide.
///
/// To add a rule: implement this interface, register the instance in
/// `RuleRegistry.allRules`, add passing/failing fixtures and tests, and
/// document it in the README rubric table. Nothing else is required.
abstract class Rule {
  /// Stable identifier, e.g. `B2_description_when`. The leading letter
  /// is the rubric category.
  String get id;

  /// Short human-readable title.
  String get title;

  /// The official guide this rule derives from:
  /// `Anthropic`, `Antigravity`, `Codex`, or `Flutter`.
  String get sourceGuide;

  /// Maximum points; negative for penalty rules (category G).
  int get maxPoints;

  /// The target profiles in which this rule is active.
  Set<Target> get targets;

  /// The severity used when no per-target override applies.
  Severity get defaultSeverity;

  /// Why the rule exists — printed by `skillscore explain`.
  String get rationale;

  /// How to fix a violation — printed by `skillscore explain` and
  /// attached to findings.
  String get fixHint;

  /// Evaluates the rule, returning awarded points plus findings.
  RuleResult evaluate(SkillDocument doc, Target target);

  /// The rubric category letter (`A`..`G`), derived from [id].
  String get category => id.substring(0, 1);
}

/// Shared helpers for rule implementations.
abstract class BaseRule implements Rule {
  @override
  String get category => id.substring(0, 1);

  /// Builds a finding for this rule with [defaultSeverity]; the scorer
  /// re-maps severity per target.
  Finding finding(String message, {int? line, String? fix}) => Finding(
        ruleId: id,
        severity: defaultSeverity,
        message: message,
        fixHint: fix ?? fixHint,
        sourceGuide: sourceGuide,
        line: line,
      );

  /// A full-score result with no findings.
  RuleResult pass() => RuleResult(points: maxPoints.toDouble());

  /// A zero-score result carrying [findings].
  RuleResult fail(List<Finding> findings) =>
      RuleResult(points: 0, findings: findings);
}
