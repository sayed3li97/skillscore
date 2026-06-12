// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import '../model/finding.dart';
import '../rules/registry.dart';
import '../scoring/scorer.dart';
import '../version.dart';

/// Renders score results as SARIF 2.1.0 so they can be displayed by
/// code-review tools (GitHub code scanning, VS Code SARIF viewers).
class SarifReporter {
  /// Creates a SARIF reporter over [registry] (used for rule metadata).
  const SarifReporter(this.registry);

  /// The registry providing rule metadata for the SARIF `rules` array.
  final RuleRegistry registry;

  /// Renders [results] as a SARIF 2.1.0 JSON document.
  String report(List<ScoreResult> results) {
    final sarif = {
      r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'skillscore',
              'version': packageVersion,
              'informationUri': 'https://github.com/sayed3li97/skillscore',
              'rules': [
                for (final rule in registry.rules)
                  {
                    'id': rule.id,
                    'name': _pascal(rule.id),
                    'shortDescription': {'text': rule.title},
                    'fullDescription': {'text': rule.rationale},
                    'help': {'text': rule.fixHint},
                    'properties': {
                      'sourceGuide': rule.sourceGuide,
                      'maxPoints': rule.maxPoints,
                    },
                  },
              ],
            },
          },
          'results': [
            for (final result in results)
              for (final finding in result.findings) _result(result, finding),
          ],
        },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(sarif);
  }

  Map<String, Object?> _result(ScoreResult result, Finding finding) => {
        'ruleId': finding.ruleId,
        'level': switch (finding.severity) {
          Severity.error => 'error',
          Severity.warning => 'warning',
          Severity.info => 'note',
        },
        'message': {
          'text': '${finding.message} Fix: ${finding.fixHint}',
        },
        'locations': [
          {
            'physicalLocation': {
              'artifactLocation': {
                'uri': result.doc.manifestPath.replaceAll(r'\', '/'),
              },
              if (finding.line != null) 'region': {'startLine': finding.line},
            },
          },
        ],
      };

  String _pascal(String id) => id
      .split('_')
      .map((part) =>
          part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
      .join();
}
