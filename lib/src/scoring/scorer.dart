// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../model/skill_document.dart';
import '../rules/registry.dart';
import '../tokens/token_counter.dart';

/// Awarded vs. maximum points for one rubric category.
class CategoryScore {
  /// Creates a category score.
  const CategoryScore({
    required this.category,
    required this.awarded,
    required this.max,
  });

  /// The category letter (`A`..`G`).
  final String category;

  /// Points awarded across the category's active rules. Negative for
  /// the penalty category G.
  final double awarded;

  /// Maximum points across the category's active rules (0 for G).
  final int max;

  /// The category's human-readable name.
  String get name => categoryNames[category] ?? category;
}

/// The complete scoring result for one skill.
class ScoreResult {
  /// Creates a score result.
  const ScoreResult({
    required this.doc,
    required this.target,
    required this.score,
    required this.grade,
    required this.categories,
    required this.penalty,
    required this.findings,
    this.tokenCounts,
  });

  /// The scored skill.
  final SkillDocument doc;

  /// The target profile used.
  final Target target;

  /// The final 0..100 score.
  final int score;

  /// The letter grade: A 90-100, B 80-89, C 70-79, D 60-69, F below 60.
  final String grade;

  /// Per-category breakdown, in category order A..G.
  final List<CategoryScore> categories;

  /// The applied category-G penalty (0 or negative, capped at -15).
  final double penalty;

  /// All findings, sorted by category, then rule id, then line.
  final List<Finding> findings;

  /// BPE token counts for the description field and the full manifest.
  /// Null when the CLI was invoked without a [TokenCounter].
  final TokenCounts? tokenCounts;

  /// Whether any finding has the given [severity].
  bool hasSeverity(Severity severity) =>
      findings.any((f) => f.severity == severity);
}

/// Converts a 0..100 [score] to its letter grade.
String gradeFor(int score) {
  if (score >= 90) return 'A';
  if (score >= 80) return 'B';
  if (score >= 70) return 'C';
  if (score >= 60) return 'D';
  return 'F';
}

/// Evaluates skills against the active rule set and computes scores.
///
/// Scoring is deterministic: the same document and target always
/// produce the same score and the same finding order.
class Scorer {
  /// Creates a scorer over [registry].
  ///
  /// Provide [tokenCounter] to include BPE token counts in each [ScoreResult].
  /// Omit it (or pass null) to skip token counting — useful in unit tests.
  Scorer(this.registry, {this.tokenCounter});

  /// The rule registry to score against.
  final RuleRegistry registry;

  /// Optional token counter. When non-null, each [ScoreResult] will carry
  /// a populated [ScoreResult.tokenCounts].
  final TokenCounter? tokenCounter;

  /// Scores [doc] under [target].
  ///
  /// Positive rules are summed and normalized to a 0..100 scale over
  /// the points achievable in the active profile (the universal profile
  /// totals exactly 100, so it is unchanged). The capped category-G
  /// penalty is then applied and the result clamped to 0..100.
  ScoreResult score(SkillDocument doc, Target target) {
    final active = registry.activeRules(target);
    var awarded = 0.0;
    var achievable = 0;
    var rawPenalty = 0.0;
    final findings = <Finding>[];
    final byCategory = <String, List<double>>{};
    final maxByCategory = <String, int>{};

    for (final rule in active) {
      final result = rule.evaluate(doc, target);
      final severity = registry.effectiveSeverity(rule, target);
      findings.addAll(result.findings.map((f) => f.withSeverity(severity)));
      byCategory.putIfAbsent(rule.category, () => []).add(result.points);
      if (rule.maxPoints > 0) {
        awarded += result.points;
        achievable += rule.maxPoints;
        maxByCategory[rule.category] =
            (maxByCategory[rule.category] ?? 0) + rule.maxPoints;
      } else {
        rawPenalty += result.points;
        maxByCategory.putIfAbsent(rule.category, () => 0);
      }
    }

    final penalty = rawPenalty < safetyPenaltyCap
        ? safetyPenaltyCap.toDouble()
        : rawPenalty;
    final normalized = achievable == 0 ? 0.0 : awarded / achievable * 100;
    final score = (normalized + penalty).clamp(0, 100).round();

    findings.sort((a, b) {
      final cat = a.category.compareTo(b.category);
      if (cat != 0) return cat;
      final rule = a.ruleId.compareTo(b.ruleId);
      if (rule != 0) return rule;
      return (a.line ?? 0).compareTo(b.line ?? 0);
    });

    final categories = <CategoryScore>[];
    final letters = byCategory.keys.toList()..sort();
    for (final letter in letters) {
      final points = byCategory[letter]!.fold<double>(0, (sum, p) => sum + p);
      categories.add(CategoryScore(
        category: letter,
        awarded: letter == 'G'
            ? (points < safetyPenaltyCap ? safetyPenaltyCap.toDouble() : points)
            : points,
        max: maxByCategory[letter] ?? 0,
      ));
    }

    return ScoreResult(
      doc: doc,
      target: target,
      score: score,
      grade: gradeFor(score),
      categories: categories,
      penalty: penalty,
      findings: findings,
      tokenCounts: tokenCounter?.tokenize(
        description: doc.description,
        manifest: doc.rawContent,
      ),
    );
  }
}
