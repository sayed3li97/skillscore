// SPDX-License-Identifier: Apache-2.0

/// How serious a finding is.
enum Severity {
  /// Breaks discovery or validity of the skill.
  error,

  /// Hurts the quality of the skill.
  warning,

  /// Nice to have; an improvement opportunity.
  info,
}

/// The agent platform whose authoring rules are being applied.
enum Target {
  /// Anthropic Claude (Claude Code) authoring guide.
  claude,

  /// Google Antigravity authoring guide.
  antigravity,

  /// OpenAI Codex authoring guide.
  codex,

  /// The union of all guides, with the most lenient severity where
  /// the guides differ. A universal-passing skill is portable.
  universal,
}

/// Parses a [Target] from its lowercase name, or returns `null`.
Target? targetFromName(String name) {
  for (final t in Target.values) {
    if (t.name == name) return t;
  }
  return null;
}

/// A single actionable issue discovered while evaluating a skill.
class Finding {
  /// Creates a finding.
  const Finding({
    required this.ruleId,
    required this.severity,
    required this.message,
    required this.fixHint,
    required this.sourceGuide,
    this.line,
  });

  /// The id of the rule that produced this finding, e.g. `B2_description_when`.
  final String ruleId;

  /// The effective severity (after any per-target override).
  final Severity severity;

  /// A one-line, human-readable description of the problem.
  final String message;

  /// A short hint describing how to fix the problem.
  final String fixHint;

  /// The official guide the rule derives from
  /// (`Anthropic`, `Antigravity`, `Codex`, or `Flutter`).
  final String sourceGuide;

  /// The 1-based line number in the manifest, when known.
  final int? line;

  /// The rubric category letter (`A`..`G`), derived from [ruleId].
  String get category => ruleId.substring(0, 1);

  /// Returns a copy of this finding with a different [severity].
  Finding withSeverity(Severity severity) => Finding(
        ruleId: ruleId,
        severity: severity,
        message: message,
        fixHint: fixHint,
        sourceGuide: sourceGuide,
        line: line,
      );
}
