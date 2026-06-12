// SPDX-License-Identifier: Apache-2.0

// ignore_for_file: avoid_print

import 'package:skillscore/skillscore.dart';

void main() {
  final parser = SkillParser();
  final registry = RuleRegistry();
  final scorer = Scorer(registry);

  for (final manifest in parser.discoverManifests('skills/')) {
    final doc = parser.parseFile(manifest);
    final result = scorer.score(doc, Target.universal);
    print('${doc.displayName}: ${result.score}/100 ${result.grade}');
    for (final finding in result.findings) {
      print('  [${finding.severity.name}] ${finding.ruleId}: '
          '${finding.message}');
    }
  }
}
