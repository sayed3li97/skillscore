// SPDX-License-Identifier: Apache-2.0

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

  static const _stopWords = {
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'shall',
    'should',
    'may',
    'might',
    'must',
    'can',
    'could',
    'for',
    'to',
    'of',
    'in',
    'on',
    'at',
    'by',
    'with',
    'from',
    'as',
    'and',
    'or',
    'not',
    'but',
    'if',
    'so',
    'this',
    'that',
    'it',
    'its',
    'me',
    'my',
    'you',
    'your',
    'we',
    'our',
    'them',
    'their',
    'i',
    'us',
    'use',
    'when',
    'user',
    'users',
    'asks',
    'ask',
    'wants',
    'want',
    'need',
    'needs',
    'please',
    'help',
    'get',
    'make',
    'let',
    'like',
  };

  // Scaffold prefixes to strip before extracting content terms.
  static final _triggerPrefix =
      RegExp(r'^use when\b.*?\bto\b\s*', caseSensitive: false);
  static final _boundaryPrefix = RegExp(
      r'^(do not use|not (for|intended for)|cannot)\s*(for\s*)?',
      caseSensitive: false);

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

    final triggerTerms = _clauseTerms(description,
        RegExp(r'use when[^.!?]*', caseSensitive: false), _triggerPrefix);
    final boundaryTerms = _clauseTerms(
        description,
        RegExp(r'(do not use|not for|cannot)[^.!?]*', caseSensitive: false),
        _boundaryPrefix);
    final whatTerms = _tokenize(description.split(RegExp(r'[.!?]')).first);

    final qTerms = _tokenize(query);

    // Only penalise on terms exclusive to the boundary clause — terms shared
    // with trigger/what context (e.g. "pdf" in "Do not use for scanned PDFs")
    // are not distinctive and must not block trigger queries.
    final combined = triggerTerms.union(whatTerms);
    final exclusiveBoundary = boundaryTerms.difference(combined);

    if (exclusiveBoundary.isNotEmpty &&
        exclusiveBoundary.intersection(qTerms).isNotEmpty) {
      return 0.05;
    }

    final matches = combined.intersection(qTerms).length;
    if (matches == 0) return 0.08;
    if (matches == 1) return 0.68;
    return 0.92;
  }

  Set<String> _clauseTerms(String text, RegExp clause, RegExp stripPrefix) {
    final match = clause.firstMatch(text.toLowerCase());
    if (match == null) return {};
    final raw = match.group(0) ?? '';
    final stripped = raw.replaceFirst(stripPrefix, '');
    return _tokenize(stripped);
  }

  Set<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .map(_stem)
      .toSet();

  // Minimal suffix stripping: covers common -s / -ing / -ed / -tion forms.
  static String _stem(String w) {
    if (w.length > 5 && w.endsWith('ing')) return w.substring(0, w.length - 3);
    if (w.length > 5 && w.endsWith('tion')) return w.substring(0, w.length - 4);
    if (w.length > 4 && w.endsWith('ed')) return w.substring(0, w.length - 2);
    if (w.length > 4 && w.endsWith('es')) return w.substring(0, w.length - 1);
    if (w.length > 4 && w.endsWith('s')) return w.substring(0, w.length - 1);
    return w;
  }

  // Maps call index to roughly [-1, 1] with a period of 7.
  static double _wave(int i) => ((i % 7) - 3) / 3.5;
}
