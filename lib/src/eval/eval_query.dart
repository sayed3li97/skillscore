// SPDX-License-Identifier: Apache-2.0

/// A single eval query with its expected trigger behaviour.
class EvalQuery {
  /// Creates an eval query.
  const EvalQuery({
    required this.query,
    required this.shouldTrigger,
    this.id,
  });

  /// Optional stable identifier used in reports (e.g. "t01", "n05").
  final String? id;

  /// The user message sent to the model.
  final String query;

  /// Whether this query is expected to activate the skill.
  final bool shouldTrigger;

  /// Parses from a JSON object.
  factory EvalQuery.fromJson(Map<String, dynamic> json) {
    final query = json['query'];
    if (query is! String || query.trim().isEmpty) {
      throw FormatException('eval query must have a non-empty "query" string');
    }
    final shouldTrigger = json['should_trigger'];
    if (shouldTrigger is! bool) {
      throw FormatException(
          'eval query must have a boolean "should_trigger" field');
    }
    return EvalQuery(
      id: json['id'] as String?,
      query: query.trim(),
      shouldTrigger: shouldTrigger,
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'query': query,
        'should_trigger': shouldTrigger,
      };

  @override
  String toString() =>
      'EvalQuery(${shouldTrigger ? "trigger" : "non-trigger"}: "$query")';
}
