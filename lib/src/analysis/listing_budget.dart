// SPDX-License-Identifier: Apache-2.0

import 'conflicts.dart' show SkillEntry;

/// The routing window: an agent runtime truncates each skill's `description`
/// at this many characters when deciding whether to invoke it, so anything
/// past this point is invisible to the routing agent. Kept in sync with the
/// 250-character limit that rule `B6_description_truncation` enforces per
/// skill; this analysis applies the same fact across a whole set of skills.
const int routingDescriptionLimit = 250;

/// One skill's contribution to the always-on skill listing.
class ListingEntry {
  /// Creates a listing entry.
  const ListingEntry({
    required this.name,
    required this.path,
    required this.descriptionChars,
    required this.tokensCl100k,
    required this.tokensClaude,
  });

  /// Display name (frontmatter `name` or folder name).
  final String name;

  /// The manifest path, for reporting.
  final String path;

  /// Character length of the skill's `description` as written.
  final int descriptionChars;

  /// cl100k_base tokens this skill adds to the always-on listing (its
  /// `name` plus `description`, the pair the runtime concatenates).
  final int tokensCl100k;

  /// Estimated Claude tokens for the same name + description pair.
  final int tokensClaude;

  /// Whether the description overflows the 250-character routing window, so
  /// its tail never reaches the routing agent (see rule B6).
  bool get overflowsRoutingWindow => descriptionChars > routingDescriptionLimit;

  /// Characters of the description past the routing window (0 when within it).
  int get overflowChars =>
      overflowsRoutingWindow ? descriptionChars - routingDescriptionLimit : 0;
}

/// A folder-level **skill listing budget**: the summed `name` + `description`
/// tokens of every installed skill.
///
/// Agent runtimes concatenate that listing into the system prompt on every
/// request so they can decide which skill (if any) to load — a cost paid
/// unconditionally, whether or not any skill is ever invoked. No single
/// skill's score reveals it, because it is an emergent property of the whole
/// set: as more skills are installed the listing grows, and once it is too
/// large skills are silently dropped from the prompt or mis-routed. This makes
/// the aggregate visible and lets a CI gate cap it.
class ListingBudget {
  /// Creates a listing budget from its per-skill [entries].
  const ListingBudget({required this.entries});

  /// Every skill's listing entry, largest token cost first.
  final List<ListingEntry> entries;

  /// Number of skills in the listing.
  int get skillCount => entries.length;

  /// Total cl100k_base tokens the listing adds to every prompt.
  int get totalCl100k => entries.fold(0, (sum, e) => sum + e.tokensCl100k);

  /// Total estimated Claude tokens the listing adds to every prompt.
  int get totalClaude => entries.fold(0, (sum, e) => sum + e.tokensClaude);

  /// Entries whose description overflows the 250-character routing window.
  List<ListingEntry> get overflowing => [
        for (final e in entries)
          if (e.overflowsRoutingWindow) e
      ];
}

/// Builds a [ListingBudget] from skill identities. The token-counting function
/// is injected (typically `TokenCounter.count`) so this analysis stays free of
/// `dart:io` and safe to compile to JS/Wasm for the web.
class ListingBudgetAnalyzer {
  /// Creates an analyzer that measures listing entries with [_countTokens].
  const ListingBudgetAnalyzer(this._countTokens);

  /// Counts cl100k_base tokens in a string.
  final int Function(String text) _countTokens;

  /// Computes the listing budget for [skills], largest token cost first.
  ///
  /// A skill with an empty description still counts its `name`, which the
  /// runtime always lists. Entries are sorted by token cost descending, ties
  /// broken by name, so output is deterministic.
  ListingBudget analyze(Iterable<SkillEntry> skills) {
    final entries = <ListingEntry>[];
    for (final s in skills) {
      // The runtime lists the name and description together; count them as one
      // block (newline-joined) so the total reflects the real concatenation.
      final listingText =
          s.description.isEmpty ? s.name : '${s.name}\n${s.description}';
      final cl100k = _countTokens(listingText);
      entries.add(ListingEntry(
        name: s.name,
        path: s.path,
        descriptionChars: s.description.length,
        tokensCl100k: cl100k,
        tokensClaude: (cl100k * 1.10).ceil(),
      ));
    }
    entries.sort((a, b) {
      final byTokens = b.tokensCl100k.compareTo(a.tokensCl100k);
      return byTokens != 0 ? byTokens : a.name.compareTo(b.name);
    });
    return ListingBudget(entries: entries);
  }
}
