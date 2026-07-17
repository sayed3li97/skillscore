// SPDX-License-Identifier: Apache-2.0

import '../analysis/skill_terms.dart';
import 'eval_api_client.dart';

/// The eval client used by [EvalRunner].
///
/// Scores each query by matching its content words against three semantic
/// regions extracted from the skill description: the trigger clause ("use
/// when …"), the boundary clause ("do not use …"), and the opening sentence.
/// No network call, no API key, no cost — runs fully offline in every
/// environment.
///
/// See the README for the full algorithm diagram.
class HeuristicEvalClient implements EvalApiClient {
  /// Creates a heuristic client.
  const HeuristicEvalClient();

  // Incremented each call to introduce slight deterministic variation,
  // simulating the stochasticity a live model would exhibit across runs.
  static int _callIndex = 0;

  // Queries that express meta-curiosity rather than task intent.
  static final _metaPattern = RegExp(
    r'^(what is |what are |tell me |explain |describe |how do i install |'
    r'write (a )?(unit )?test|debug why |summaris[ez]|history of |'
    r'alternatives to |what are the alternatives)',
    caseSensitive: false,
  );

  @override
  Future<TriggerCheckResult> checkTrigger({
    required String skillName,
    required String skillDescription,
    required String query,
  }) async {
    final idx = _callIndex++;
    final p = _probability(query.trim(), skillDescription);
    // Deterministic wave noise: ±7% cycling across successive calls.
    final noise = _wave(idx) * 0.07;
    return TriggerCheckResult(triggered: (p + noise) >= 0.5);
  }

  double _probability(String query, String description) {
    if (_metaPattern.hasMatch(query)) return 0.04;

    // The trigger surface (use-when clause + opening sentence) is what a
    // request matches against; only terms exclusive to the boundary clause
    // (e.g. "scanned" in "Do not use for scanned PDFs") block a match.
    final surface = triggerSurface(description);
    final exclusiveBoundary = exclusiveBoundaryTerms(description);
    final qTerms = tokenizeTerms(query);

    if (exclusiveBoundary.isNotEmpty &&
        exclusiveBoundary.intersection(qTerms).isNotEmpty) {
      return 0.05;
    }

    final matches = surface.intersection(qTerms).length;
    if (matches == 0) return 0.08;
    if (matches == 1) return 0.68;
    return 0.92;
  }

  // Maps call index to roughly [-1, 1] with a period of 7.
  static double _wave(int i) => ((i % 7) - 3) / 3.5;
}
