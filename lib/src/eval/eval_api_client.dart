// SPDX-License-Identifier: Apache-2.0

/// The result of a single skill-trigger check.
class TriggerCheckResult {
  /// Creates a trigger check result.
  const TriggerCheckResult({required this.triggered, this.error});

  /// Whether the skill was selected for this query.
  final bool triggered;

  /// Non-null when the check failed (e.g. unexpected internal error).
  final String? error;

  /// True when [error] is non-null.
  bool get hasError => error != null;
}

/// Interface for eval clients so [EvalRunner] can be tested with a fake.
///
/// The only built-in implementation is [HeuristicEvalClient], which runs
/// fully offline using term-overlap scoring — no network, no API key.
abstract class EvalApiClient {
  /// Scores [query] against [skillDescription] and returns whether it should
  /// trigger the skill identified by [skillName].
  Future<TriggerCheckResult> checkTrigger({
    required String skillName,
    required String skillDescription,
    required String query,
  });
}
