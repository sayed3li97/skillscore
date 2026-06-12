# skillscore examples

## CLI

```bash
# Score one skill
skillscore my-skill/

# Score a monorepo of skills against the Claude ruleset, as JSON
skillscore skills/ --target claude --format json

# CI gate: fail when any skill is below 80
skillscore skills/ --min-score 80

# Understand a finding
skillscore explain B2_description_when
```

## Library

```dart
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
```
