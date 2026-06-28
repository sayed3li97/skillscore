// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

/// C1: the manifest body is at most 500 lines. Source: Anthropic.
class BodyLengthRule extends BaseRule {
  @override
  String get id => 'C1_body_length';
  @override
  String get title => 'Body is 500 lines or fewer';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 6;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'Anthropic recommends keeping SKILL.md under 500 lines; the whole '
      'body is loaded into context when the skill activates, so every extra '
      'line is a recurring token cost.';
  @override
  String get fixHint =>
      'Move deep reference material into references/ or examples/ files and '
      'link to them from the manifest. For bodies that are inherently long, '
      'add a hierarchy layer with explicit navigation pointers, e.g. '
      '"## Reference\\n> See references/api.md for the full parameter list."';

  /// Scoring: full 6 points at <=500 lines, degrading linearly to 0 at
  /// 1000 lines: `points = 6 * (1000 - lines) / 500`, clamped to 0..6.
  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final lines = doc.bodyLines.length;
    if (lines <= 500) return pass();
    final points = (6 * (1000 - lines) / 500).clamp(0, 6).toDouble();
    return RuleResult(points: points, findings: [
      finding(
        'Body is $lines lines; Anthropic recommends 500 or fewer.',
        line: doc.bodyLineNumber(500),
      ),
    ]);
  }
}

/// C2: no explainer bloat — sentences that define common knowledge the
/// model already has. Source: Anthropic.
class ExplainerBloatRule extends BaseRule {
  @override
  String get id => 'C2_explainer_bloat';
  @override
  String get title => 'No explainer bloat (defining common knowledge)';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 5;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'The model already knows what JSON, HTTP, or Flutter are. Explaining '
      'common knowledge burns context tokens without changing behavior.';
  @override
  String get fixHint =>
      'Delete definitional sentences; state only project-specific facts the '
      'model cannot know.';

  static final List<RegExp> _bloat = [
    RegExp(
        r'is an? (popular |widely[- ]used |well[- ]known |modern |free |'
        r'open[- ]source )*(programming language|framework|library|'
        r'piece of software|software program|markup language|data format|'
        r'protocol|package manager|version control system|text editor|'
        r'operating system|database)',
        caseSensitive: false),
    RegExp(
        r'\b(JSON|HTTP|HTTPS|HTML|YAML|XML|CSS|SQL|REST)\b '
        r'(stands for|is short for|is an acronym)',
        caseSensitive: false),
    RegExp(r'\b(widgets?|a widget) (is|are) (the )?(basic )?building blocks?',
        caseSensitive: false),
  ];

  /// Scoring: each flagged line costs 2.5 points:
  /// `points = max(0, 5 - 2.5 * flaggedLines)`.
  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final findings = <Finding>[];
    final prose = doc.proseLines;
    for (var i = 0; i < prose.length; i++) {
      for (final pattern in _bloat) {
        if (pattern.hasMatch(prose[i])) {
          findings.add(finding(
            'Explains common knowledge: "${_trim(prose[i])}"',
            line: doc.bodyLineNumber(i),
          ));
          break;
        }
      }
    }
    if (findings.isEmpty) return pass();
    final points = (5 - 2.5 * findings.length).clamp(0, 5).toDouble();
    return RuleResult(points: points, findings: findings);
  }

  String _trim(String line) {
    final t = line.trim();
    return t.length <= 60 ? t : '${t.substring(0, 57)}...';
  }
}

/// C3: no excessive optionality ("you can use X, or Y, or Z, or...").
/// Source: Anthropic.
class ExcessiveOptionalityRule extends BaseRule {
  @override
  String get id => 'C3_excessive_optionality';
  @override
  String get title => 'No excessive optionality (long "or" chains)';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.info;
  @override
  String get rationale =>
      'Skills exist to make decisions for the agent. Offering many '
      'interchangeable options pushes the decision back onto the model and '
      'produces inconsistent results.';
  @override
  String get fixHint =>
      'Pick the one recommended option and state it; mention alternatives '
      'only with a rule for when to prefer them.';

  static final RegExp _orChain = RegExp(r',\s*or\s+', caseSensitive: false);

  /// Scoring: each line with two or more ", or" connectors costs 2
  /// points: `points = max(0, 4 - 2 * flaggedLines)`.
  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final findings = <Finding>[];
    final prose = doc.proseLines;
    for (var i = 0; i < prose.length; i++) {
      if (_orChain.allMatches(prose[i]).length >= 2) {
        findings.add(finding(
          'Long option chain offers several interchangeable choices.',
          line: doc.bodyLineNumber(i),
        ));
      }
    }
    if (findings.isEmpty) return pass();
    final points = (4 - 2 * findings.length).clamp(0, 4).toDouble();
    return RuleResult(points: points, findings: findings);
  }
}
