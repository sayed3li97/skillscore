// SPDX-License-Identifier: Apache-2.0

import 'eval_query.dart';

/// The schema version this code understands.
const int evalSchemaVersion = 1;

/// Default number of scoring runs per query.
const int defaultRunsPerQuery = 3;

/// Default fraction of runs that must trigger for a trigger query to pass.
const double defaultTriggerThreshold = 0.5;

/// Parsed representation of an `evals.json` file.
///
/// The file lives next to `SKILL.md` and defines trigger / non-trigger
/// queries that the eval runner uses to measure the skill's trigger rate.
class EvalDocument {
  /// Creates an eval document.
  const EvalDocument({
    required this.skillName,
    this.version = evalSchemaVersion,
    this.runsPerQuery = defaultRunsPerQuery,
    this.triggerThreshold = defaultTriggerThreshold,
    required this.queries,
  });

  /// The name field from the skill's frontmatter (used as the tool name).
  final String skillName;

  /// Schema version — currently always 1.
  final int version;

  /// Number of scoring runs per query (default: 3).
  final int runsPerQuery;

  /// Minimum trigger rate for trigger queries to pass (default: 0.5).
  final double triggerThreshold;

  /// All queries in document order.
  final List<EvalQuery> queries;

  /// Queries with [EvalQuery.shouldTrigger] == true.
  List<EvalQuery> get triggerQueries =>
      queries.where((q) => q.shouldTrigger).toList();

  /// Queries with [EvalQuery.shouldTrigger] == false.
  List<EvalQuery> get nonTriggerQueries =>
      queries.where((q) => !q.shouldTrigger).toList();

  /// Parses from a JSON object, throwing [FormatException] on invalid data.
  factory EvalDocument.fromJson(Map<String, dynamic> json) {
    final skill = json['skill'];
    if (skill is! String || skill.trim().isEmpty) {
      throw const FormatException(
          'evals.json must have a non-empty "skill" string');
    }
    final version = json['version'] ?? evalSchemaVersion;
    if (version is! int) {
      throw const FormatException('"version" must be an integer');
    }
    final runsPerQuery = json['runs_per_query'] ?? defaultRunsPerQuery;
    if (runsPerQuery is! int || runsPerQuery < 1 || runsPerQuery > 20) {
      throw const FormatException(
          '"runs_per_query" must be an integer between 1 and 20');
    }
    final threshold = json['trigger_threshold'];
    final triggerThreshold = threshold == null
        ? defaultTriggerThreshold
        : (threshold is num ? threshold.toDouble() : null);
    if (triggerThreshold == null ||
        triggerThreshold < 0.0 ||
        triggerThreshold > 1.0) {
      throw const FormatException(
          '"trigger_threshold" must be a number between 0.0 and 1.0');
    }
    // "model" is silently ignored — eval runs are always offline.
    final rawQueries = json['queries'];
    if (rawQueries is! List || rawQueries.isEmpty) {
      throw const FormatException(
          '"queries" must be a non-empty array of query objects');
    }
    final queries = <EvalQuery>[];
    for (var i = 0; i < rawQueries.length; i++) {
      final q = rawQueries[i];
      if (q is! Map<String, dynamic>) {
        throw FormatException('queries[$i] must be an object');
      }
      try {
        queries.add(EvalQuery.fromJson(q));
      } on FormatException catch (e) {
        throw FormatException('queries[$i]: ${e.message}');
      }
    }
    return EvalDocument(
      skillName: skill.trim(),
      version: version,
      runsPerQuery: runsPerQuery,
      triggerThreshold: triggerThreshold,
      queries: List.unmodifiable(queries),
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'skill': skillName,
        'version': version,
        'runs_per_query': runsPerQuery,
        'trigger_threshold': triggerThreshold,
        'queries': queries.map((q) => q.toJson()).toList(),
      };
}
