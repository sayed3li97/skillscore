// SPDX-License-Identifier: Apache-2.0

import 'skill_terms.dart';

/// One skill's identity for cross-skill analysis (conflict detection and
/// listing-budget accounting).
class SkillEntry {
  /// Creates a skill entry.
  const SkillEntry({
    required this.name,
    required this.path,
    required this.description,
  });

  /// Display name (frontmatter `name` or folder name).
  final String name;

  /// The manifest path, for reporting.
  final String path;

  /// The frontmatter `description`, or empty when missing.
  final String description;
}

/// A pair of skills whose trigger surfaces overlap enough that an agent may
/// load the wrong one for the same request.
class SkillConflict {
  /// Creates a conflict record.
  const SkillConflict({
    required this.a,
    required this.b,
    required this.overlap,
    required this.shared,
    required this.aHasBoundary,
    required this.bHasBoundary,
  });

  /// The two overlapping skills.
  final SkillEntry a;

  /// The second of the two overlapping skills.
  final SkillEntry b;

  /// Containment overlap in `0..1`: shared terms over the smaller surface. A
  /// high value means one skill's triggers are largely a subset of the
  /// other's, so they compete for the same requests.
  final double overlap;

  /// The shared trigger terms, sorted.
  final List<String> shared;

  /// Whether [a] declares a distinguishing boundary ("do not use ...") clause.
  final bool aHasBoundary;

  /// Whether [b] declares a distinguishing boundary clause.
  final bool bHasBoundary;

  /// Whether both skills already carry a boundary clause, which reduces (but
  /// does not remove) the risk of the agent confusing them.
  bool get bothBounded => aHasBoundary && bHasBoundary;
}

/// Detects cross-skill trigger overlap. Deterministic and offline: it compares
/// the trigger surface (the `use when` clause plus the opening sentence) of
/// every pair of descriptions. Two skills whose surfaces overlap enough will
/// compete for the same requests, and the agent may load the wrong one.
class ConflictDetector {
  /// Creates a detector.
  const ConflictDetector({this.threshold = 0.5, this.minShared = 2});

  /// Containment overlap at or above which a pair is flagged (`0..1`).
  final double threshold;

  /// A pair needs at least this many shared terms to be flagged, which keeps
  /// tiny descriptions from producing noise.
  final int minShared;

  /// Every overlapping pair among [skills], most-overlapping first.
  List<SkillConflict> analyze(List<SkillEntry> skills) {
    final surfaces = [for (final s in skills) triggerSurface(s.description)];
    final bounded = [
      for (final s in skills) exclusiveBoundaryTerms(s.description).isNotEmpty,
    ];
    final conflicts = <SkillConflict>[];
    for (var i = 0; i < skills.length; i++) {
      for (var j = i + 1; j < skills.length; j++) {
        final ta = surfaces[i];
        final tb = surfaces[j];
        if (ta.isEmpty || tb.isEmpty) continue;
        final shared = ta.intersection(tb);
        if (shared.length < minShared) continue;
        final smaller = ta.length < tb.length ? ta.length : tb.length;
        final overlap = shared.length / smaller;
        if (overlap + 1e-9 < threshold) continue;
        conflicts.add(SkillConflict(
          a: skills[i],
          b: skills[j],
          overlap: overlap,
          shared: shared.toList()..sort(),
          aHasBoundary: bounded[i],
          bHasBoundary: bounded[j],
        ));
      }
    }
    conflicts.sort((x, y) {
      final byOverlap = y.overlap.compareTo(x.overlap);
      if (byOverlap != 0) return byOverlap;
      final byA = x.a.name.compareTo(y.a.name);
      return byA != 0 ? byA : x.b.name.compareTo(y.b.name);
    });
    return conflicts;
  }
}
