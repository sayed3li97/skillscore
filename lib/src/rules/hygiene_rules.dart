// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

/// F1: no time-sensitive absolute statements that will rot, unless
/// inside a `<details>` block of old patterns. Source: Anthropic.
class TimeSensitiveRule extends BaseRule {
  @override
  String get id => 'F1_time_sensitive';
  @override
  String get title => 'No time-sensitive statements that will rot';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'Statements like "as of 2024 use the old API" silently become wrong. '
      'Skills are read long after they are written; date-anchored advice '
      'rots in place.';
  @override
  String get fixHint =>
      'State the current rule unconditionally; move historical notes into a '
      '<details> block labeled as old patterns.';

  static final RegExp _dated = RegExp(
    r'\b(before|after|until|by|as of|starting|since)\s+'
    r'((January|February|March|April|May|June|July|August|September|'
    r'October|November|December)\s+\d{4}|\d{4})\b',
    caseSensitive: false,
  );

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final findings = <Finding>[];
    var inDetails = false;
    final prose = doc.proseLines;
    for (var i = 0; i < prose.length; i++) {
      final line = prose[i];
      if (line.contains('<details')) inDetails = true;
      if (line.contains('</details>')) {
        inDetails = false;
        continue;
      }
      if (inDetails) continue;
      final m = _dated.firstMatch(line);
      if (m != null) {
        findings.add(finding(
          'Time-sensitive statement "${m.group(0)}" will rot.',
          line: doc.bodyLineNumber(i),
        ));
      }
    }
    return findings.isEmpty ? pass() : fail(findings);
  }
}

/// F2: paths use forward slashes only. Source: Anthropic.
class ForwardSlashesRule extends BaseRule {
  @override
  String get id => 'F2_forward_slashes';
  @override
  String get title => 'Paths use forward slashes only';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 3;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.error;
  @override
  String get rationale =>
      'Forward slashes work on every platform agents run on; backslash '
      'paths break on macOS and Linux and confuse path handling.';
  @override
  String get fixHint =>
      r'Rewrite paths with forward slashes: scripts/run.py, not '
      r'scripts\run.py or C:\skills\run.py.';

  static final List<RegExp> _backslashPath = [
    RegExp(r'\b[A-Za-z]:\\\S+'), // drive letter: C:\foo
    RegExp(r'\b\w+\\\w+\\\w+'), // two separators: a\b\c
    RegExp(r'\b\w+\\\w+\.\w+'), // file with extension: scripts\run.py
  ];

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final findings = <Finding>[];
    final prose = doc.proseLines;
    for (var i = 0; i < prose.length; i++) {
      for (final pattern in _backslashPath) {
        final m = pattern.firstMatch(prose[i]);
        if (m != null) {
          findings.add(finding(
            'Backslash-style path "${m.group(0)}" found.',
            line: doc.bodyLineNumber(i),
          ));
          break;
        }
      }
    }
    return findings.isEmpty ? pass() : fail(findings);
  }
}

/// F3: consistent terminology — conservative synonym-mixing check.
/// Source: Anthropic.
class ConsistentTerminologyRule extends BaseRule {
  @override
  String get id => 'F3_consistent_terminology';
  @override
  String get title => 'Consistent terminology (no synonym mixing)';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 3;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.info;
  @override
  String get rationale =>
      'Calling one concept by several names ("endpoint" vs "route") makes '
      'the model treat them as different things. One concept, one term.';
  @override
  String get fixHint =>
      'Pick one term per concept and use it everywhere in the skill.';

  /// Synonym groups checked. Deliberately small and conservative: a
  /// group is flagged only when two of its terms each appear at least
  /// twice in the body prose.
  static const List<List<String>> synonymGroups = [
    ['endpoint', 'route'],
    ['folder', 'directory'],
    ['parameter', 'argument'],
  ];

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final prose = doc.proseLines.join('\n').toLowerCase();
    final findings = <Finding>[];
    for (final group in synonymGroups) {
      final frequent = group.where((term) {
        final count = RegExp('\\b$term(s|es)?\\b').allMatches(prose).length;
        return count >= 2;
      }).toList();
      if (frequent.length >= 2) {
        findings.add(finding(
          'Mixes synonyms for one concept: ${frequent.join(' / ')}.',
        ));
      }
    }
    return findings.isEmpty ? pass() : fail(findings);
  }
}
