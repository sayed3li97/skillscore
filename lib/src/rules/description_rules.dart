// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

/// Action verbs that signal a description states WHAT the skill does.
const List<String> _actionVerbs = [
  'analyze', 'audit', 'build', 'check', 'compile', 'convert', 'create',
  'debug', 'deploy', 'detect', 'draft', 'evaluate', 'export', 'extract',
  'fill', 'find', 'fix', 'format', 'generate', 'identify', 'implement',
  'import', 'lint', 'manage', 'migrate', 'parse', 'plan', 'process',
  'produce', 'refactor', 'render', 'report', 'review', 'run', 'scan',
  'score', 'search', 'summarize', 'sync', 'test', 'transform', 'translate',
  'update', 'validate', 'verify', 'write', // base forms
];

bool _isActionVerb(String word) {
  final w = word.toLowerCase();
  for (final verb in _actionVerbs) {
    if (w == verb || w == '${verb}s' || w == '${verb}es') return true;
  }
  return false;
}

/// B1: the description states WHAT the skill does, ideally opening
/// with an action verb. Source: all three guides (cited as Anthropic).
class DescriptionWhatRule extends BaseRule {
  @override
  String get id => 'B1_description_what';
  @override
  String get title => 'Description states WHAT the skill does';
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
      'All three guides agree the description is the biggest discovery '
      'factor. Opening with a concrete action verb tells the agent exactly '
      'what capability the skill provides.';
  @override
  String get fixHint =>
      'Open the description with an action verb, e.g. "Generates ...", '
      '"Validates ...", "Converts ...".';

  /// Scoring: 6 points when the first word is an action verb; 3 when an
  /// action verb appears later in the first sentence; otherwise 0.
  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) return const RuleResult(points: 0);
    final words = description
        .split(RegExp(r'[^A-Za-z]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const RuleResult(points: 0);
    if (_isActionVerb(words.first)) return pass();
    final firstSentence = description.split(RegExp(r'[.!?]')).first;
    final sentenceWords =
        firstSentence.split(RegExp(r'[^A-Za-z]+')).where((w) => w.isNotEmpty);
    if (sentenceWords.any(_isActionVerb)) {
      return RuleResult(points: 3, findings: [
        finding(
          'Description mentions an action but does not open with one.',
          line: doc.descriptionLine,
          fix: 'Move the action verb to the front: "Generates X ..." instead '
              'of "A skill that generates X ...".',
        ),
      ]);
    }
    return fail([
      finding(
        'Description does not state what the skill does with an action verb.',
        line: doc.descriptionLine,
      ),
    ]);
  }
}

/// B2: the description states WHEN to use the skill. Source: all three
/// guides (cited as Anthropic).
class DescriptionWhenRule extends BaseRule {
  @override
  String get id => 'B2_description_when';
  @override
  String get title => 'Description states WHEN to use the skill';
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
      'Agents match the user request against the description. Without '
      'explicit trigger conditions ("Use when ..."), the skill activates '
      'unreliably — too often, or never.';
  @override
  String get fixHint =>
      'Add a trigger clause such as "Use when the user asks to ..." listing '
      'the situations that should activate the skill.';

  static final RegExp _triggers = RegExp(
    r'\b(use (this skill |this |it )?when|when the user|when a user|'
    r'when you need|when working (with|on)|when asked|use (this |it )?for|'
    r'use (this skill |this |it )?if|triggers? when|applies when|'
    r'invoke (this |it )?when|for (tasks|requests|questions) (that|involving|'
    r'about))\b',
    caseSensitive: false,
  );

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) return const RuleResult(points: 0);
    if (_triggers.hasMatch(description)) return pass();
    return fail([
      finding(
        'Description has no trigger clause saying when to use the skill.',
        line: doc.descriptionLine,
      ),
    ]);
  }
}

/// B3: the description is written in third person. Source: Anthropic,
/// Antigravity.
class ThirdPersonRule extends BaseRule {
  @override
  String get id => 'B3_third_person';
  @override
  String get title => 'Description is written in third person';
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
      'The description is read by the agent, not spoken by it. First or '
      'second person ("I can...", "you can...") reads as conversation and '
      'matches user requests poorly.';
  @override
  String get fixHint =>
      'Rewrite in third person: "Processes PDF files..." instead of '
      '"I can process PDF files..." or "You can use this to...".';

  static final List<RegExp> _markers = [
    RegExp(r'\bI\b'), // case-sensitive on purpose
    RegExp(r"\bI'(m|ll|ve)\b"),
    RegExp(r'\byou can\b', caseSensitive: false),
    RegExp(r'\byou should\b', caseSensitive: false),
    RegExp(r'\bwe\b', caseSensitive: false),
  ];

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) return const RuleResult(points: 0);
    final hits = <String>[];
    for (final marker in _markers) {
      final m = marker.firstMatch(description);
      if (m != null) hits.add('"${m.group(0)}"');
    }
    if (hits.isEmpty) return pass();
    return fail([
      finding(
        'Description uses first/second person: ${hits.join(', ')}.',
        line: doc.descriptionLine,
      ),
    ]);
  }
}

/// B4: the first ~60 characters front-load concrete trigger keywords
/// instead of filler. Source: Codex. Active for codex and universal.
class FrontloadedTriggersRule extends BaseRule {
  @override
  String get id => 'B4_frontloaded_triggers';
  @override
  String get title => 'Description front-loads concrete trigger keywords';
  @override
  String get sourceGuide => 'Codex';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => const {Target.codex, Target.universal};
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'Codex truncates and ranks on the start of the description. Filler '
      'openings like "A tool that helps with..." spend the most valuable '
      'characters on nothing.';
  @override
  String get fixHint =>
      'Put the concrete capability and keywords in the first 60 characters; '
      'delete openers like "helps with", "a tool that", "this skill".';

  static final List<RegExp> _filler = [
    RegExp(r'helps? with', caseSensitive: false),
    RegExp(r'\ba (handy |simple |powerful )?(tool|utility|helper) (that|for)',
        caseSensitive: false),
    RegExp(r'\bthis (skill|tool)\b', caseSensitive: false),
    RegExp(r'\ba skill (that|for|to)\b', caseSensitive: false),
    RegExp(r'\b(is )?used to\b', caseSensitive: false),
    RegExp(r'\b(allows|enables) you\b', caseSensitive: false),
    RegExp(r'\bdesigned to\b', caseSensitive: false),
  ];

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) return const RuleResult(points: 0);
    final head = description.substring(0, math.min(60, description.length));
    final hit = _filler.where((f) => f.hasMatch(head)).toList();
    if (hit.isEmpty) return pass();
    return fail([
      finding(
        'The first 60 characters of the description contain filler '
        '("${hit.first.firstMatch(head)!.group(0)}") instead of concrete '
        'trigger keywords.',
        line: doc.descriptionLine,
      ),
    ]);
  }
}

/// B6: the description's opening 250 characters are self-contained.
/// Claude's auto-invocation context truncates descriptions at 250
/// characters; content beyond that is invisible to the routing agent.
/// Source: Anthropic. Active for claude and universal.
class DescriptionTruncationRule extends BaseRule {
  @override
  String get id => 'B6_description_truncation';
  @override
  String get title => 'Description is self-contained within 250 characters';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 3;
  @override
  Set<Target> get targets => const {Target.claude, Target.universal};
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      "Claude's auto-invocation context truncates descriptions at 250 "
      "characters. A description that passes A4's 1024-character limit can "
      'still lose its trigger clause or action verb at the exact point where '
      'the routing agent decides whether to invoke the skill.';
  @override
  String get fixHint =>
      'Put the action verb and trigger clause entirely within the first '
      '250 characters. Trim or restructure if needed — the opening window '
      'is the only part the routing agent sees.';

  static const int _limit = 250;

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) return const RuleResult(points: 0);
    if (description.length <= _limit) return pass();
    return fail([
      finding(
        'Description is ${description.length} characters; Claude truncates '
        'at $_limit. The trigger clause may be invisible to the routing agent.',
        line: doc.descriptionLine,
      ),
    ]);
  }
}

/// B5: the description includes a boundary / "do not use" clause to
/// prevent over-activation. Source: Antigravity. Active for
/// antigravity and universal.
class BoundaryClauseRule extends BaseRule {
  @override
  String get id => 'B5_boundary_clause';
  @override
  String get title => 'Description includes a boundary ("do not use") clause';
  @override
  String get sourceGuide => 'Antigravity';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => const {Target.antigravity, Target.universal};
  @override
  Severity get defaultSeverity => Severity.info;
  @override
  String get rationale =>
      'Antigravity recommends stating what a skill is NOT for. Without a '
      'boundary, broad descriptions cause the skill to activate on requests '
      'it cannot handle.';
  @override
  String get fixHint =>
      'Append a boundary, e.g. "Do not use for scanned/image-only PDFs."';

  static final RegExp _boundary = RegExp(
    r"\b(do not use|don't use|not for|does not (handle|cover|support)|"
    r'avoid using|only use|not intended for|out of scope|not suitable for|'
    r'skip (this|it) (for|when))\b',
    caseSensitive: false,
  );

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) return const RuleResult(points: 0);
    if (_boundary.hasMatch(description)) return pass();
    return fail([
      finding(
        'Description has no boundary clause saying when NOT to use the '
        'skill.',
        line: doc.descriptionLine,
      ),
    ]);
  }
}
