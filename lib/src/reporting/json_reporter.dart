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

  Map<String, Object?> _skill(ScoreResult result) {
    final tc = result.tokenCounts;
    return {
      'name': result.doc.displayName,
      'path': result.doc.manifestPath,
      'score': result.score,
      'grade': result.grade,
      'penalty': result.penalty,
      if (tc != null)
        'tokens': {
          'encoding': 'cl100k_base',
          'claudeNote':
              'Claude estimate applies +10% overhead to cl100k_base counts '
                  '(within ~5-8% of actual Anthropic API counts for English prose).',
          'description': {
            'scope': 'permanent: loaded on every prompt for skill discovery',
            'gpt4': tc.descriptionCl100k,
            'claudeEstimate': tc.descriptionClaude,
          },
          'manifest': {
            'scope': 'active: loaded only when the skill is invoked',
            'gpt4': tc.manifestCl100k,
            'claudeEstimate': tc.manifestClaude,
          },
        },
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
}
