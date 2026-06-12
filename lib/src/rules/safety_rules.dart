// SPDX-License-Identifier: Apache-2.0

import 'package:path/path.dart' as p;

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

/// G1: skills with scripts or terminal/infra commands must have a
/// "Safety" section. Penalty rule. Source: Antigravity. Active for
/// antigravity and universal.
class SafetySectionRule extends BaseRule {
  @override
  String get id => 'G1_safety_section';
  @override
  String get title => 'Scripts/commands are covered by a Safety section';
  @override
  String get sourceGuide => 'Antigravity';
  @override
  int get maxPoints => -8;
  @override
  Set<Target> get targets => const {Target.antigravity, Target.universal};
  @override
  Severity get defaultSeverity => Severity.error;
  @override
  String get rationale =>
      'Antigravity requires skills that run commands to describe what those '
      'commands do, so the agent (and its user) can assess blast radius '
      'before execution.';
  @override
  String get fixHint =>
      'Add a "## Safety" section describing what each script/command does, '
      'what it touches, and what the agent must never run unattended.';

  static final RegExp _safetyHeading =
      RegExp(r'^#{1,6}\s*.*\bsafety\b', caseSensitive: false);

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    if (!doc.hasScriptsOrCommands) return const RuleResult(points: 0);
    if (doc.bodyLines.any(_safetyHeading.hasMatch)) {
      return const RuleResult(points: 0);
    }
    return RuleResult(points: maxPoints.toDouble(), findings: [
      finding(
        'Skill ships scripts or terminal commands but has no Safety '
        'section.',
        line: doc.bodyStartLine,
      ),
    ]);
  }
}

/// G2: bundled scripts are documented — how to run them, their
/// arguments, and whether to execute or read each one. Penalty rule.
/// Source: Anthropic, Antigravity.
class ScriptDocsRule extends BaseRule {
  @override
  String get id => 'G2_script_docs';
  @override
  String get title => 'Bundled scripts are documented (run command, args)';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => -7;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'An undocumented script forces the agent to reverse-engineer it, '
      'wasting tokens and risking wrong invocations. Both Anthropic and '
      'Antigravity say to document how to run each bundled script.';
  @override
  String get fixHint =>
      'For each file in scripts/, document the run command and its '
      'arguments, and state whether the agent should execute it or read it.';

  static final RegExp _runWords = RegExp(
    r'\b(run|execute|invoke|usage|arguments?|args)\b',
    caseSensitive: false,
  );

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    if (doc.scripts.isEmpty) return const RuleResult(points: 0);
    final mentioned =
        doc.scripts.any((s) => doc.body.contains(p.basename(s.relativePath)));
    final hasRunDocs = _runWords.hasMatch(doc.body);
    if (mentioned && hasRunDocs) return const RuleResult(points: 0);
    return RuleResult(points: maxPoints.toDouble(), findings: [
      finding(
        mentioned
            ? 'Scripts are mentioned but the body never explains how to '
                'run them or what arguments they take.'
            : 'Files in scripts/ are never mentioned in the manifest.',
        line: doc.bodyStartLine,
      ),
    ]);
  }
}
