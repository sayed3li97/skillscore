// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('A1_frontmatter_present', () {
    final rule = FrontmatterPresentRule();
    test('passes with valid frontmatter', () {
      expect(evaluate(rule, manifestWith()).points, 4);
    });
    test('fails when frontmatter is missing', () {
      final result = evaluate(rule, '# no frontmatter');
      expect(result.points, 0);
      expect(result.findings.single.message, contains('No YAML frontmatter'));
    });
    test('fails on malformed YAML', () {
      final result = evaluate(rule, '---\nname: [oops\n---\nbody');
      expect(result.points, 0);
      expect(result.findings.single.message, contains('Malformed'));
    });
  });

  group('A2_name_format', () {
    final rule = NameFormatRule();
    test('passes a lowercase hyphenated name', () {
      expect(evaluate(rule, manifestWith(name: 'pdf-filler-2')).points, 4);
    });
    test('fails when name is missing', () {
      final result = evaluate(rule, '---\ndescription: D.\n---\n');
      expect(result.points, 0);
      expect(result.findings.single.message, contains('no "name"'));
    });
    test('fails on uppercase and underscores', () {
      final result = evaluate(rule, manifestWith(name: 'My_Skill'));
      expect(result.points, 0);
      expect(result.findings.single.message, contains('lowercase'));
    });
    test('fails on names longer than 64 characters', () {
      final result = evaluate(rule, manifestWith(name: 'a' * 65));
      expect(result.points, 0);
      expect(result.findings.single.message, contains('limit is 64'));
    });
    test('fails on non-ascii names', () {
      final result = evaluate(rule, manifestWith(name: '企業-スキル'));
      expect(result.points, 0);
    });
  });

  group('A3_name_reserved_words', () {
    final rule = NameReservedWordsRule();
    test('passes a normal name', () {
      expect(evaluate(rule, manifestWith(name: 'code-reviewer')).points, 3);
    });
    test('fails when name contains claude', () {
      final result = evaluate(rule, manifestWith(name: 'claude-helper'));
      expect(result.points, 0);
      expect(result.findings.single.message, contains('claude'));
    });
    test('fails when name contains anthropic', () {
      final result = evaluate(rule, manifestWith(name: 'anthropic-tools'));
      expect(result.points, 0);
    });
    test('awards nothing without findings when name is missing', () {
      final result = evaluate(rule, '---\ndescription: D.\n---\n');
      expect(result.points, 0);
      expect(result.findings, isEmpty);
    });
    test('is ERROR on claude target, INFO elsewhere', () {
      final registry = RuleRegistry();
      final r = registry.byId('A3_name_reserved_words')!;
      expect(registry.effectiveSeverity(r, Target.claude), Severity.error);
      expect(registry.effectiveSeverity(r, Target.universal), Severity.info);
      expect(registry.effectiveSeverity(r, Target.codex), Severity.info);
    });
  });

  group('A4_description_present', () {
    final rule = DescriptionPresentRule();
    test('passes a normal description', () {
      expect(evaluate(rule, manifestWith()).points, 4);
    });
    test('fails when description is missing', () {
      final result = evaluate(rule, '---\nname: x\n---\n');
      expect(result.points, 0);
    });
    test('fails when description is empty', () {
      final result = evaluate(rule, "---\nname: x\ndescription: ''\n---\n");
      expect(result.points, 0);
    });
    test('fails when description exceeds 1024 characters', () {
      final result = evaluate(rule, manifestWith(description: 'word ' * 300));
      expect(result.points, 0);
      expect(result.findings.single.message, contains('1024'));
    });
  });
}
