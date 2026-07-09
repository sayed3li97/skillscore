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

  group('A5_frontmatter_keys', () {
    final rule = FrontmatterKeysRule();

    test('passes when only recognized keys are present', () {
      expect(evaluate(rule, manifestWith()).points, 2);
    });

    test('passes recognized optional keys', () {
      const manifest = '---\n'
          'name: x\n'
          'description: A skill. Use when asked.\n'
          'license: MIT\n'
          'allowed-tools: [Read, Write]\n'
          'version: "1.0"\n'
          'metadata:\n'
          '  author: someone\n'
          '---\n';
      expect(evaluate(rule, manifest).points, 2);
    });

    test('does not flag nested keys under metadata', () {
      const manifest = '---\n'
          'name: x\n'
          'description: A skill. Use when asked.\n'
          'metadata:\n'
          '  custom-field: value\n'
          '  another: 3\n'
          '---\n';
      expect(evaluate(rule, manifest).points, 2);
    });

    test('flags an unknown key', () {
      const manifest = '---\n'
          'name: x\n'
          'description: A skill. Use when asked.\n'
          'author: someone\n'
          '---\n';
      final result = evaluate(rule, manifest);
      expect(result.points, 0);
      expect(result.findings.single.message, contains('author'));
    });

    test('suggests the closest key for a typo', () {
      const manifest = '---\n'
          'name: x\n'
          'descrption: A skill. Use when asked.\n'
          '---\n';
      final result = evaluate(rule, manifest);
      expect(result.points, 0);
      expect(result.findings.single.message, contains('Did you mean'));
      expect(result.findings.single.message, contains('description'));
    });

    test('reports the line of the unknown key', () {
      const manifest = '---\n'
          'name: x\n'
          'description: A skill. Use when asked.\n'
          'bogus: value\n'
          '---\n';
      final result = evaluate(rule, manifest);
      expect(result.findings.single.line, 4);
    });

    test('reports every unknown key', () {
      const manifest = '---\n'
          'name: x\n'
          'description: A skill. Use when asked.\n'
          'foo: 1\n'
          'bar: 2\n'
          '---\n';
      final result = evaluate(rule, manifest);
      expect(result.findings.length, 2);
    });

    test('stays silent when frontmatter is missing', () {
      final result = evaluate(rule, '# no frontmatter');
      expect(result.points, 0);
      expect(result.findings, isEmpty);
    });

    test('defaults to WARNING severity', () {
      final registry = RuleRegistry();
      final r = registry.byId('A5_frontmatter_keys')!;
      expect(registry.effectiveSeverity(r, Target.universal), Severity.warning);
    });

    test('attaches a safe fix when the typo has a suggestion', () {
      const manifest = '---\n'
          'name: x\n'
          'descrption: A skill. Use when asked.\n'
          '---\n';
      final f = evaluate(rule, manifest).findings.single;
      expect(f.isFixable, isTrue);
      expect(f.fix!.fromKey, 'descrption');
      expect(f.fix!.toKey, 'description');
      expect(f.fix!.line, 3);
      expect(f.fix!.summary, 'rename "descrption" to "description"');
    });

    test('attaches no fix for an unknown key with no near match', () {
      const manifest = '---\n'
          'name: x\n'
          'description: A skill. Use when asked.\n'
          'author: me\n'
          '---\n';
      final f = evaluate(rule, manifest).findings.single;
      expect(f.isFixable, isFalse);
    });
  });
}
