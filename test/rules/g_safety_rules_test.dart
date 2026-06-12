// SPDX-License-Identifier: Apache-2.0

import 'package:path/path.dart' as p;
import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final parser = SkillParser();

  group('G applicability', () {
    test('skill without scripts or commands is exempt', () {
      final doc = parseDoc(manifestWith(body: 'Just prose, no commands.'));
      expect(doc.hasScriptsOrCommands, isFalse);
      expect(SafetySectionRule().evaluate(doc, Target.universal).points, 0);
      expect(ScriptDocsRule().evaluate(doc, Target.universal).points, 0);
    });
    test('bash fences and scripts/ references trigger applicability', () {
      expect(
          parseDoc(manifestWith(body: '```bash\nls\n```')).hasScriptsOrCommands,
          isTrue);
      expect(
          parseDoc(manifestWith(body: 'See scripts/run.sh'))
              .hasScriptsOrCommands,
          isTrue);
      expect(parseDoc(manifestWith(body: r'$ rm -rf tmp')).hasScriptsOrCommands,
          isTrue);
    });
  });

  group('G1_safety_section', () {
    final rule = SafetySectionRule();
    test('is active only for antigravity and universal', () {
      expect(rule.targets, {Target.antigravity, Target.universal});
    });
    test('no penalty when a Safety section exists', () {
      final result = evaluate(rule,
          manifestWith(body: '```bash\nls\n```\n\n## Safety\nRead-only.'));
      expect(result.points, 0);
    });
    test('penalizes commands without a Safety section', () {
      final result =
          evaluate(rule, manifestWith(body: '```bash\nrm -rf build\n```'));
      expect(result.points, -8);
      expect(result.findings.single.severity, Severity.error);
    });
  });

  group('G2_script_docs', () {
    final rule = ScriptDocsRule();
    test('no penalty when scripts are documented', () {
      inTempSkill({
        'SKILL.md': manifestWith(
            body: 'Run `python scripts/fill.py input output` with two '
                'arguments.\n\n## Safety\nWrites only the output file.'),
        'scripts/fill.py': 'pass',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(rule.evaluate(doc, Target.universal).points, 0);
      });
    });
    test('penalizes undocumented scripts', () {
      inTempSkill({
        'SKILL.md': manifestWith(body: 'This skill processes data files.'),
        'scripts/mystery.py': 'pass',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        final result = rule.evaluate(doc, Target.universal);
        expect(result.points, -7);
        expect(result.findings.single.message, contains('never mentioned'));
      });
    });
  });
}
