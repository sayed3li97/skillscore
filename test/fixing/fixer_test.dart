// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final rule = FrontmatterKeysRule();

  // The A5 findings (with any attached fixes) for the skill at [root].
  List<Finding> a5Findings(String root) => rule
      .evaluate(SkillParser().parseFile('$root/SKILL.md'), Target.universal)
      .findings;

  group('SkillFixer', () {
    test('renames a misspelled frontmatter key in place', () {
      inTempSkill({
        'SKILL.md':
            '---\nname: x\ndescrption: A skill. Use when asked.\n---\nBody.',
      }, (root) {
        final path = '$root/SKILL.md';
        final result = const SkillFixer().fix(path, a5Findings(root));
        expect(result.applied, hasLength(1));
        expect(result.applied.single.fromKey, 'descrption');
        expect(result.applied.single.toKey, 'description');
        final content = File(path).readAsStringSync();
        expect(content, contains('description: A skill. Use when asked.'));
        expect(content, isNot(contains('descrption')));
      });
    });

    test('leaves an unsuggestable unknown key untouched', () {
      inTempSkill({
        'SKILL.md': '---\nname: x\n'
            'description: A skill. Use when asked.\nauthor: me\n---\nBody.',
      }, (root) {
        final path = '$root/SKILL.md';
        final result = const SkillFixer().fix(path, a5Findings(root));
        expect(result.applied, isEmpty);
        expect(File(path).readAsStringSync(), contains('author: me'));
      });
    });

    test('is idempotent: a second run makes no further change', () {
      inTempSkill({
        'SKILL.md':
            '---\nname: x\ndescrption: A skill. Use when asked.\n---\nBody.',
      }, (root) {
        final path = '$root/SKILL.md';
        expect(const SkillFixer().fix(path, a5Findings(root)).applied,
            hasLength(1));
        // Re-parsing sees "description" now, so A5 no longer flags it.
        expect(const SkillFixer().fix(path, a5Findings(root)).applied, isEmpty);
      });
    });

    test('preserves the value and every surrounding line', () {
      inTempSkill({
        'SKILL.md': '---\nname: keep-me\n'
            'descrption: Do a thing. Use when asked.\nversion: "1.0"\n'
            '---\n# Body\nkeep this.',
      }, (root) {
        final path = '$root/SKILL.md';
        const SkillFixer().fix(path, a5Findings(root));
        final content = File(path).readAsStringSync();
        expect(content, contains('name: keep-me'));
        expect(content, contains('description: Do a thing. Use when asked.'));
        expect(content, contains('version: "1.0"'));
        expect(content, contains('keep this.'));
      });
    });

    test('preserves CRLF line endings', () {
      inTempSkill({
        'SKILL.md': '---\r\nname: x\r\n'
            'descrption: A skill. Use when asked.\r\n---\r\nBody.',
      }, (root) {
        final path = '$root/SKILL.md';
        const SkillFixer().fix(path, a5Findings(root));
        final content = File(path).readAsStringSync();
        expect(content, contains('\r\n'));
        expect(content, contains('description: A skill. Use when asked.'));
      });
    });

    test('does nothing when no finding carries a fix', () {
      inTempSkill({
        'SKILL.md':
            '---\nname: x\ndescription: A skill. Use when asked.\n---\nBody.',
      }, (root) {
        final path = '$root/SKILL.md';
        final before = File(path).readAsStringSync();
        final result = const SkillFixer().fix(path, a5Findings(root));
        expect(result.changed, isFalse);
        expect(File(path).readAsStringSync(), before);
      });
    });
  });
}
