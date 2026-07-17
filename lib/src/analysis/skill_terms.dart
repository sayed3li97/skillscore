// SPDX-License-Identifier: Apache-2.0

/// Shared content-word extraction for skill descriptions.
///
/// A skill's **trigger surface** is the set of content terms that make an
/// agent match a request to it: the `use when ...` clause plus the opening
/// sentence of the description, minus scaffold and stop words, lightly
/// stemmed. The eval heuristic and the cross-skill conflict detector both
/// define "what this skill triggers on" the same way through this module.
library;

/// Words with no discriminating value for trigger matching.
const Set<String> skillStopWords = {
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'shall',
  'should', 'may', 'might', 'must', 'can', 'could', 'for', 'to', 'of', 'in',
  'on', 'at', 'by', 'with', 'from', 'as', 'and', 'or', 'not', 'but', 'if',
  'so', 'this', 'that', 'it', 'its', 'me', 'my', 'you', 'your', 'we', 'our',
  'them', 'their', 'i', 'us', 'use', 'when', 'user', 'users', 'asks', 'ask',
  'wants', 'want', 'need', 'needs', 'please', 'help', 'get', 'make', 'let',
  'like', //
};

final RegExp _triggerClause = RegExp(r'use when[^.!?]*', caseSensitive: false);
final RegExp _triggerPrefix =
    RegExp(r'^use when\b.*?\bto\b\s*', caseSensitive: false);
final RegExp _boundaryClause =
    RegExp(r'(do not use|not for|cannot)[^.!?]*', caseSensitive: false);
final RegExp _boundaryPrefix = RegExp(
    r'^(do not use|not (for|intended for)|cannot)\s*(for\s*)?',
    caseSensitive: false);

/// Minimal suffix stripping: common `-s` / `-ing` / `-ed` / `-tion` forms.
String stemTerm(String w) {
  if (w.length > 5 && w.endsWith('ing')) return w.substring(0, w.length - 3);
  if (w.length > 5 && w.endsWith('tion')) return w.substring(0, w.length - 4);
  if (w.length > 4 && w.endsWith('ed')) return w.substring(0, w.length - 2);
  if (w.length > 4 && w.endsWith('es')) return w.substring(0, w.length - 1);
  if (w.length > 4 && w.endsWith('s')) return w.substring(0, w.length - 1);
  return w;
}

/// Lowercases [text], splits on non-alphanumerics, drops short and stop
/// words, and stems the rest into a deduplicated set.
Set<String> tokenizeTerms(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.length > 2 && !skillStopWords.contains(w))
    .map(stemTerm)
    .toSet();

Set<String> _clauseTerms(String text, RegExp clause, RegExp stripPrefix) {
  final match = clause.firstMatch(text.toLowerCase());
  if (match == null) return {};
  return tokenizeTerms((match.group(0) ?? '').replaceFirst(stripPrefix, ''));
}

/// The positive trigger surface of [description]: the `use when` clause terms
/// unioned with the opening-sentence terms. These are what a request matches
/// against, so two skills whose surfaces overlap compete for the same
/// requests.
Set<String> triggerSurface(String description) {
  final trigger = _clauseTerms(description, _triggerClause, _triggerPrefix);
  final what = tokenizeTerms(description.split(RegExp(r'[.!?]')).first);
  return trigger.union(what);
}

/// The boundary ("do not use") terms of [description] that are not also part
/// of its trigger surface, i.e. the distinctive exclusions.
Set<String> exclusiveBoundaryTerms(String description) {
  final boundary = _clauseTerms(description, _boundaryClause, _boundaryPrefix);
  return boundary.difference(triggerSurface(description));
}
