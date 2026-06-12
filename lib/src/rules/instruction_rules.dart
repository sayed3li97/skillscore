// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

/// E1: the body states anti-patterns explicitly ("do not", "never",
/// "avoid"), not only the happy path. Source: Flutter official skills
/// practice, Anthropic.
class AntiPatternsRule extends BaseRule {
  @override
  String get id => 'E1_anti_patterns';
  @override
  String get title => 'States anti-patterns explicitly';
  @override
  String get sourceGuide => 'Flutter';
  @override
  int get maxPoints => 6;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'Models follow prohibitions well but cannot infer them. The official '
      'Flutter skills devote whole sections to "do not"; a skill that only '
      'shows the happy path leaves failure modes open.';
  @override
  String get fixHint =>
      'Add explicit prohibitions: "Do not edit generated files", "Never '
      'commit secrets", "Avoid X; prefer Y".';

  static final RegExp _prohibition = RegExp(
    r"\b(do not|don't|never|avoid|must not)\b",
    caseSensitive: false,
  );

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    if (_prohibition.hasMatch(doc.body)) return pass();
    return fail([
      finding(
        'Body contains no explicit anti-patterns (no "do not", "never", '
        'or "avoid").',
        line: doc.bodyStartLine,
      ),
    ]);
  }
}

/// E2: multi-step tasks use a checklist or numbered workflow.
/// Source: Anthropic, Flutter.
class WorkflowChecklistRule extends BaseRule {
  @override
  String get id => 'E2_workflow_checklist';
  @override
  String get title => 'Uses a checklist or numbered workflow';
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
      'Numbered steps and checklists keep multi-step work on track and let '
      'the agent verify progress; prose workflows get skipped or reordered.';
  @override
  String get fixHint =>
      'Convert the workflow into an ordered list ("1. ... 2. ...") or a '
      'markdown task list ("- [ ] ...").';

  static final RegExp _ordered = RegExp(r'^\s*\d+[.)]\s+\S');
  static final RegExp _taskItem = RegExp(r'^\s*[-*]\s+\[[ xX]\]\s');

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    var consecutive = 0;
    for (final line in doc.bodyLines) {
      if (_taskItem.hasMatch(line)) return pass();
      if (_ordered.hasMatch(line)) {
        consecutive++;
        if (consecutive >= 2) return pass();
      } else if (line.trim().isNotEmpty) {
        consecutive = 0;
      }
    }
    return fail([
      finding(
        'No checklist ("- [ ]") or numbered workflow found in the body.',
        line: doc.bodyStartLine,
      ),
    ]);
  }
}

/// E3: the body includes a feedback or validation loop (verify, then
/// fix and repeat). Source: Anthropic.
class FeedbackLoopRule extends BaseRule {
  @override
  String get id => 'E3_feedback_loop';
  @override
  String get title => 'Includes a feedback/validation loop';
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
      'The biggest quality lever in agent workflows: run a validator '
      '(analyzer, tests, linter), fix what it reports, and repeat until '
      'clean. Skills without a loop ship unverified output.';
  @override
  String get fixHint =>
      'Add a validation step, e.g. "Run the tests; if any fail, fix the '
      'code and re-run until they pass."';

  static final RegExp _verify = RegExp(
    r'\b(analy[sz]er?|tests?|testing|valid(at\w+)?|lint(er|ing)?|'
    r'type[- ]?check\w*|verif\w+)\b',
    caseSensitive: false,
  );
  static final RegExp _iterate = RegExp(
    r'\b(fix(es|ing)?|repeat\w*|until|re-?run\w*|iterate|again|retry)\b',
    caseSensitive: false,
  );

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    if (_verify.hasMatch(doc.body) && _iterate.hasMatch(doc.body)) {
      return pass();
    }
    return fail([
      finding(
        'No feedback loop: the body never says to validate output and fix '
        'failures until clean.',
        line: doc.bodyStartLine,
      ),
    ]);
  }
}

/// E4: the body contains at least one concrete fenced code example.
/// Source: Anthropic.
class CodeExampleRule extends BaseRule {
  @override
  String get id => 'E4_code_example';
  @override
  String get title => 'Contains a concrete fenced code example';
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
      'One concrete example anchors the abstract instructions; models '
      'imitate examples far more reliably than they follow descriptions.';
  @override
  String get fixHint =>
      'Add a fenced code block (```...```) showing one real, complete '
      'example of the expected input or output.';

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    var inFence = false;
    var fenceHasContent = false;
    for (final line in doc.bodyLines) {
      if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) {
        if (inFence && fenceHasContent) return pass();
        inFence = !inFence;
        fenceHasContent = false;
        continue;
      }
      if (inFence && line.trim().isNotEmpty) fenceHasContent = true;
    }
    return fail([
      finding(
        'No fenced code example found in the body.',
        line: doc.bodyStartLine,
      ),
    ]);
  }
}
