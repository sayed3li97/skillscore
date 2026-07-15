// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'dart:convert';

import '../model/finding.dart';

/// A recorded backlog of accepted findings, so a CI gate can fail only on
/// **new** findings (regressions) while tolerating a pre-existing set. This is
/// the escape hatch that lets a team turn `--min-score` or a strict gate on an
/// established fleet of skills without fixing everything first, the same idea
/// as ESLint bulk suppressions and Ruff's baseline.
///
/// Findings are keyed by `"<relative manifest path>\t<rule id>"` with a count,
/// which is stable across line-number shifts (fixing an unrelated line does not
/// invalidate the baseline). Info-level findings are ignored: the baseline
/// governs the same error/warning scope a gate cares about.
class Baseline {
  /// Creates a baseline from per-key accepted counts.
  const Baseline(this.counts);

  /// `"<relPath>\t<ruleId>"` maps to the number of accepted findings.
  final Map<String, int> counts;

  /// Whether [f] is in scope for the baseline (info is advisory, never gated).
  static bool _gated(Finding f) => f.severity != Severity.info;

  /// The fingerprint key for [finding] under [relativePath].
  static String keyFor(String relativePath, Finding finding) =>
      '$relativePath\t${finding.ruleId}';

  /// Records every gated finding in [entries] (relative path to its findings).
  factory Baseline.record(Map<String, List<Finding>> entries) {
    final counts = <String, int>{};
    entries.forEach((rel, findings) {
      for (final f in findings) {
        if (!_gated(f)) continue;
        counts.update(keyFor(rel, f), (v) => v + 1, ifAbsent: () => 1);
      }
    });
    return Baseline(counts);
  }

  /// Parses a baseline JSON document, throwing [FormatException] on malformed
  /// input.
  factory Baseline.parse(String jsonText) {
    final Object? decoded = jsonDecode(jsonText);
    if (decoded is! Map || decoded['findings'] is! Map) {
      throw const FormatException('not a skillscore baseline document');
    }
    final counts = <String, int>{};
    (decoded['findings'] as Map).forEach((k, v) {
      if (v is int) counts['$k'] = v;
    });
    return Baseline(counts);
  }

  /// Serializes to a stable, sorted JSON document (deterministic output).
  String toJson() {
    final sorted = SplayTreeMap<String, int>.from(counts);
    return const JsonEncoder.withIndent('  ')
        .convert({'version': 1, 'findings': sorted});
  }

  /// Total number of accepted findings.
  int get total => counts.values.fold(0, (a, b) => a + b);

  /// The gated findings in [entries] that exceed what this baseline accepts,
  /// in input order: the regressions a gate should fail on.
  List<Finding> newFindings(Map<String, List<Finding>> entries) {
    final remaining = Map<String, int>.from(counts);
    final fresh = <Finding>[];
    entries.forEach((rel, findings) {
      for (final f in findings) {
        if (!_gated(f)) continue;
        final key = keyFor(rel, f);
        final left = remaining[key] ?? 0;
        if (left > 0) {
          remaining[key] = left - 1;
        } else {
          fresh.add(f);
        }
      }
    });
    return fresh;
  }
}
