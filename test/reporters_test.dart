// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final registry = RuleRegistry();
  final scorer = Scorer(registry);

  List<ScoreResult> scoreFixtures() {
    final parser = SkillParser();
    return [
      scorer.score(
          parser.parseFile(fixture('excellent/pdf-form-filler/SKILL.md')),
          Target.universal),
      scorer.score(
          parser.parseFile(fixture('mediocre/spreadsheet-skill/SKILL.md')),
          Target.universal),
    ];
  }

  group('pretty reporter', () {
    test('renders score, grade, categories, and findings without color', () {
      final output = PrettyReporter(color: false).report(scoreFixtures());
      expect(output, contains('Score: 100/100  Grade: A'));
      expect(output, contains('Frontmatter validity'));
      expect(output, contains('B2_description_when'));
      expect(output, contains('fix:'));
      expect(output, contains('Summary'));
      expect(output, isNot(contains('\x1B[')));
    });
    test('quiet mode prints one line per skill', () {
      final output =
          PrettyReporter(color: false, quiet: true).report(scoreFixtures());
      final lines =
          output.trim().split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines, hasLength(2));
      expect(lines.first, contains('Score: 100/100'));
    });
    test('color mode emits ANSI codes', () {
      final output = PrettyReporter(color: true).report(scoreFixtures());
      expect(output, contains('\x1B['));
    });
    test('output is deterministic', () {
      final a = PrettyReporter(color: false).report(scoreFixtures());
      final b = PrettyReporter(color: false).report(scoreFixtures());
      expect(a, b);
    });
  });

  group('json reporter', () {
    test('emits the stable documented shape', () {
      final output = const JsonReporter().report(scoreFixtures());
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['tool']['name'], 'skillscore');
      expect(decoded['target'], 'universal');
      final skills = decoded['skills'] as List;
      expect(skills, hasLength(2));
      final first = skills.first as Map<String, dynamic>;
      expect(first['score'], 100);
      expect(first['grade'], 'A');
      expect(first['categories'], isA<List>());
      final second = skills[1] as Map<String, dynamic>;
      final findings = second['findings'] as List;
      expect(findings, isNotEmpty);
      final finding = findings.first as Map<String, dynamic>;
      expect(
          finding.keys,
          containsAll([
            'ruleId',
            'severity',
            'message',
            'fixHint',
            'sourceGuide',
            'line'
          ]));
      expect(decoded['summary']['skillCount'], 2);
    });
  });

  group('sarif reporter', () {
    test('emits valid SARIF 2.1.0 structure', () {
      final output = SarifReporter(registry).report(scoreFixtures());
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['version'], '2.1.0');
      expect(decoded[r'$schema'], contains('sarif-2.1.0'));
      final runs = decoded['runs'] as List;
      expect(runs, hasLength(1));
      final driver = runs.first['tool']['driver'] as Map<String, dynamic>;
      expect(driver['name'], 'skillscore');
      final rules = driver['rules'] as List;
      expect(rules, hasLength(registry.rules.length));
      expect((rules.first as Map)['id'], 'A1_frontmatter_present');
      final results = runs.first['results'] as List;
      expect(results, isNotEmpty);
      final result = results.first as Map<String, dynamic>;
      expect(['error', 'warning', 'note'], contains(result['level']));
      final location = (result['locations'] as List).first;
      expect(
          location['physicalLocation']['artifactLocation']['uri'], isNotEmpty);
    });
  });
}
