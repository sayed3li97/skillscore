// SPDX-License-Identifier: Apache-2.0

import 'eval_document.dart';
import 'eval_query.dart';

/// Result for a single eval query — how many of its runs triggered the skill.
class QueryResult {
  /// Creates a query result.
  const QueryResult({
    required this.query,
    required this.triggerCount,
    required this.totalRuns,
    this.errors = const [],
  });

  /// The query that was evaluated.
  final EvalQuery query;

  /// Number of runs in which the skill was triggered.
  final int triggerCount;

  /// Total runs attempted (may be < [EvalDocument.runsPerQuery] if errors).
  final int totalRuns;

  /// API error messages collected during the run (non-fatal per run).
  final List<String> errors;

  /// Fraction of runs that triggered the skill (0.0 if [totalRuns] is 0).
  double get triggerRate => totalRuns == 0 ? 0.0 : triggerCount / totalRuns;

  /// Whether this result meets the [threshold] for its query type.
  bool passes(double threshold) =>
      query.shouldTrigger ? triggerRate >= threshold : triggerRate < threshold;

  /// Human-readable label: "trigger" or "non-trigger".
  String get label => query.shouldTrigger ? 'trigger' : 'non-trigger';
}

/// The complete result of running an [EvalDocument] against the API.
class EvalRunResult {
  /// Creates an eval run result.
  const EvalRunResult({
    required this.document,
    required this.skillPath,
    required this.queryResults,
  });

  /// The eval document that was run.
  final EvalDocument document;

  /// Path to the SKILL.md file that was evaluated.
  final String skillPath;

  /// Per-query results in document order.
  final List<QueryResult> queryResults;

  /// Number of queries that passed their threshold.
  int get passCount =>
      queryResults.where((r) => r.passes(document.triggerThreshold)).length;

  /// Number of queries that failed their threshold.
  int get failCount => queryResults.length - passCount;

  /// True when every query passed.
  bool get allPassed => failCount == 0;

  /// Queries that did not meet their threshold.
  List<QueryResult> get failures =>
      queryResults.where((r) => !r.passes(document.triggerThreshold)).toList();
}
