// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import '../scoring/scorer.dart';
import '../version.dart';

/// Renders score results as a stable, machine-readable JSON object
/// designed for CI pipelines and dashboards.
class JsonReporter {
  /// Creates a JSON reporter.
  const JsonReporter();

  /// Renders [results] as pretty-printed JSON.
  String report(List<ScoreResult> results) {
    final skills = results.map(_skill).toList();
    final scores = results.map((r) => r.score).toList();
    final object = {
      'tool': {'name': 'skillscore', 'version': packageVersion},
      'target': results.isEmpty ? null : results.first.target.name,
      'skills': skills,
      'summary': {
        'skillCount': results.length,
        'averageScore': scores.isEmpty
            ? null
            : (scores.reduce((a, b) => a + b) / scores.length).round(),
        'minScore':
            scores.isEmpty ? null : scores.reduce((a, b) => a < b ? a : b),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(object);
  }

  Map<String, Object?> _skill(ScoreResult result) => {
        'name': result.doc.displayName,
        'path': result.doc.manifestPath,
        'score': result.score,
        'grade': result.grade,
        'penalty': result.penalty,
        'categories': [
          for (final cat in result.categories)
            {
              'id': cat.category,
              'name': cat.name,
              'awarded': cat.awarded,
              'max': cat.max,
            },
        ],
        'findings': [
          for (final f in result.findings)
            {
              'ruleId': f.ruleId,
              'severity': f.severity.name,
              'message': f.message,
              'line': f.line,
              'fixHint': f.fixHint,
              'sourceGuide': f.sourceGuide,
            },
        ],
      };
}
