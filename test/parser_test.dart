// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final parser = SkillParser();

  group('frontmatter parsing', () {
    test('parses valid frontmatter and body with correct line numbers', () {
      final doc = parseDoc('---\nname: x-y\ndescription: Does things.\n---\n'
          '# Title\nBody line.');
      expect(doc.hasFrontmatterDelimiters, isTrue);
      expect(doc.frontmatterValid, isTrue);
      expect(doc.name, 'x-y');
      expect(doc.description, 'Does things.');
      expect(doc.nameLine, 2);
      expect(doc.descriptionLine, 3);
      expect(doc.bodyStartLine, 5);
      expect(doc.bodyLines.first, '# Title');
      expect(doc.bodyLineNumber(1), 6);
    });

    test('missing frontmatter does not crash', () {
      final doc = parseDoc('# Just a heading\nSome text.');
      expect(doc.hasFrontmatterDelimiters, isFalse);
      expect(doc.frontmatterValid, isFalse);
      expect(doc.name, isNull);
      expect(doc.bodyStartLine, 1);
    });

    test('unclosed frontmatter is reported, not thrown', () {
      final doc = parseDoc('---\nname: foo\nno closing delimiter');
      expect(doc.hasFrontmatterDelimiters, isFalse);
      expect(doc.frontmatterError, contains('no closing'));
    });

    test('malformed YAML is reported, not thrown', () {
      final doc = parseDoc('---\nname: [unclosed\n---\nbody');
      expect(doc.hasFrontmatterDelimiters, isTrue);
      expect(doc.frontmatterValid, isFalse);
      expect(doc.frontmatterError, contains('Malformed'));
    });

    test('empty frontmatter block is invalid but parsed', () {
      final doc = parseDoc('---\n---\nbody');
      expect(doc.frontmatterValid, isFalse);
      expect(doc.frontmatterError, contains('empty'));
    });

    test('strips UTF-8 BOM', () {
      final doc = parseDoc('\uFEFF---\nname: bom-skill\n---\nbody');
      expect(doc.frontmatterValid, isTrue);
      expect(doc.name, 'bom-skill');
    });

    test('CRLF line endings keep line numbers intact', () {
      final doc =
          parseDoc('---\r\nname: crlf\r\ndescription: D.\r\n---\r\nbody');
      expect(doc.name, 'crlf');
      expect(doc.nameLine, 2);
      expect(doc.bodyStartLine, 5);
      expect(doc.bodyLines.first, 'body');
    });

    test('empty file parses to an empty body', () {
      final doc = parseDoc('');
      expect(doc.hasFrontmatterDelimiters, isFalse);
      expect(doc.body, isEmpty);
    });
  });

  group('discovery', () {
    test('direct file path is scored as the manifest regardless of name', () {
      inTempSkill({'anything.md': manifestWith()}, (root) {
        final manifests = parser.discoverManifests(p.join(root, 'anything.md'));
        expect(manifests, hasLength(1));
      });
    });

    test('manifest detection is case-insensitive', () {
      for (final name in ['SKILL.md', 'skill.md', 'Skill.md']) {
        inTempSkill({name: manifestWith()}, (root) {
          final manifests = parser.discoverManifests(root);
          expect(manifests, hasLength(1), reason: name);
        });
      }
    });

    test('tree discovery finds every skill, sorted by path', () {
      inTempSkill({
        'b/SKILL.md': manifestWith(name: 'b-skill'),
        'a/skill.md': manifestWith(name: 'a-skill'),
        'a/references/notes.md': 'notes',
        'unrelated/readme.txt': 'not a skill',
      }, (root) {
        final manifests = parser.discoverManifests(root);
        expect(manifests, hasLength(2));
        expect(manifests.first, contains('a'));
        expect(manifests.last, contains('b'));
      });
    });

    test('missing path throws SkillInputException', () {
      expect(() => parser.discoverManifests('/no/such/path-xyz'),
          throwsA(isA<SkillInputException>()));
    });

    test('binary file throws SkillInputException', () {
      final dir = Directory.systemTemp.createTempSync('skillscore_bin_');
      try {
        final file = File(p.join(dir.path, 'SKILL.md'));
        file.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x00, 0x01]);
        expect(() => parser.discoverManifests(file.path),
            throwsA(isA<SkillInputException>()));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('symlinked directories are not followed', () {
      final outside = Directory.systemTemp.createTempSync('skillscore_out_');
      final dir = Directory.systemTemp.createTempSync('skillscore_sym_');
      try {
        File(p.join(outside.path, 'SKILL.md'))
            .writeAsStringSync(manifestWith());
        Link(p.join(dir.path, 'escape')).createSync(outside.path);
        final manifests = parser.discoverManifests(dir.path);
        expect(manifests, isEmpty);
      } finally {
        outside.deleteSync(recursive: true);
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('side files', () {
    test('discovers side folders deterministically', () {
      inTempSkill({
        'SKILL.md': manifestWith(),
        'references/b.md': 'b',
        'references/a.md': 'a',
        'scripts/run.sh': 'echo hi',
        'examples/e.md': 'e',
        'assets/logo.txt': 'logo',
      }, (root) {
        final doc = parser.parseFile(p.join(root, 'SKILL.md'));
        expect(doc.references.map((f) => f.relativePath),
            ['references/a.md', 'references/b.md']);
        expect(doc.scripts, hasLength(1));
        expect(doc.examples, hasLength(1));
        expect(doc.assets, hasLength(1));
      });
    });

    test('displayName falls back to folder name', () {
      final doc = parseDoc('no frontmatter here',
          path: '/skills/my-folder-name/SKILL.md');
      expect(doc.displayName, 'my-folder-name');
    });
  });
}
