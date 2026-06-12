// SPDX-License-Identifier: Apache-2.0

import 'package:path/path.dart' as p;
import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final parser = SkillParser();

  group('D1_progressive_disclosure', () {
    final rule = ProgressiveDisclosureRule();
    test('passes short bodies', () {
      expect(evaluate(rule, manifestWith(body: 'short')).points, 5);
    });
    test('fails a long body with no split', () {
      final body = List.filled(200, 'prose line').join('\n');
      final result = evaluate(rule, manifestWith(body: body));
      expect(result.points, 0);
      expect(result.findings, hasLength(1));
    });
    test('passes a long body that links local markdown', () {
      final body = '${List.filled(200, 'prose').join('\n')}\n'
          'See [ref](references/deep.md).';
      expect(evaluate(rule, manifestWith(body: body)).points, 5);
    });
    test('passes a long body with a references folder', () {
      inTempSkill({
        'SKILL.md': manifestWith(body: List.filled(200, 'prose').join('\n')),
        'references/notes.md': 'notes',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(rule.evaluate(doc, Target.universal).points, 5);
      });
    });
  });

  group('D2_one_level_links', () {
    final rule = OneLevelLinksRule();
    test('passes links one level deep', () {
      inTempSkill({
        'SKILL.md': manifestWith(body: 'See [ref](references/a.md).'),
        'references/a.md': 'Plain content, no further links.',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(rule.evaluate(doc, Target.universal).points, 5);
      });
    });
    test('flags nested link chains', () {
      inTempSkill({
        'SKILL.md': manifestWith(body: 'See [a](references/a.md).'),
        'references/a.md': 'Go deeper: [b](b.md).',
        'references/b.md': 'The real content.',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        final result = rule.evaluate(doc, Target.universal);
        expect(result.points, 2.5);
        expect(result.findings.single.message, contains('two levels'));
      });
    });
    test('ignores external links', () {
      final result = evaluate(
          rule, manifestWith(body: '[docs](https://example.com/guide.md)'));
      expect(result.points, 5);
    });
  });

  group('D3_reference_toc', () {
    final rule = ReferenceTocRule();
    final longContent =
        '# Big reference\n${List.filled(120, 'detail line').join('\n')}';
    final longWithToc = '# Big reference\n## Contents\n- [One](#one)\n'
        '${List.filled(120, 'detail line').join('\n')}';

    test('passes when long reference files have a TOC', () {
      inTempSkill({
        'SKILL.md': manifestWith(),
        'references/big.md': longWithToc,
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(rule.evaluate(doc, Target.universal).points, 5);
      });
    });
    test('flags long reference files without a TOC', () {
      inTempSkill({
        'SKILL.md': manifestWith(),
        'references/big.md': longContent,
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        final result = rule.evaluate(doc, Target.universal);
        expect(result.points, 0);
        expect(result.findings.single.message, contains('big.md'));
      });
    });
    test('awards proportional credit', () {
      inTempSkill({
        'SKILL.md': manifestWith(),
        'references/a.md': longWithToc,
        'references/b.md': longContent,
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(rule.evaluate(doc, Target.universal).points, 2.5);
      });
    });
    test('ignores short files', () {
      inTempSkill({
        'SKILL.md': manifestWith(),
        'references/short.md': 'tiny',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(rule.evaluate(doc, Target.universal).points, 5);
      });
    });
  });
}
