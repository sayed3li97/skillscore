// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Future<({int code, String out, String err})> run(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(args, out: out, err: err);
  return (code: code, out: out.toString(), err: err.toString());
}

void main() {
  group('scoring command', () {
    test('scores a skill folder and exits 0', () async {
      final result =
          await run([fixture('excellent/pdf-form-filler'), '--no-color']);
      expect(result.code, exitOk);
      expect(result.out, contains('Score: 100/100  Grade: A'));
    });

    test('scores a whole tree deterministically ordered by path', () async {
      final result = await run([fixture(''), '--no-color', '--quiet']);
      expect(result.code, exitOk);
      final lines = result.out.trim().split('\n');
      expect(lines.length, greaterThanOrEqualTo(5));
    });

    test('--format json emits parseable JSON', () async {
      final result = await run(
          [fixture('mediocre/spreadsheet-skill'), '--format', 'json']);
      expect(result.code, exitOk);
      final decoded = jsonDecode(result.out) as Map<String, dynamic>;
      expect(decoded['skills'], hasLength(1));
    });

    test('--format sarif emits SARIF 2.1.0', () async {
      final result =
          await run([fixture('broken/legacy-notes'), '--format', 'sarif']);
      expect(result.code, exitOk);
      final decoded = jsonDecode(result.out) as Map<String, dynamic>;
      expect(decoded['version'], '2.1.0');
    });

    test('--target changes active rules', () async {
      final universal = await run([
        fixture('mediocre/spreadsheet-skill'),
        '--format',
        'json',
      ]);
      final claude = await run([
        fixture('mediocre/spreadsheet-skill'),
        '--format',
        'json',
        '--target',
        'claude',
      ]);
      final uScore =
          (jsonDecode(universal.out)['skills'] as List).first['score'] as int;
      final cScore =
          (jsonDecode(claude.out)['skills'] as List).first['score'] as int;
      // The claude profile drops B4/B5, so the mediocre skill (which
      // fails B5) normalizes to a different score.
      expect(cScore, isNot(uScore));
    });
  });

  group('exit codes', () {
    test('--min-score gates the exit code', () async {
      final pass = await run(
          [fixture('excellent/pdf-form-filler'), '--min-score', '90']);
      expect(pass.code, exitOk);
      final fail = await run(
          [fixture('mediocre/spreadsheet-skill'), '--min-score', '80']);
      expect(fail.code, exitFailedGate);
    });

    test('--strict fails on warnings', () async {
      final result = await run(
          [fixture('mediocre/spreadsheet-skill'), '--strict', '--quiet']);
      expect(result.code, exitFailedGate);
    });

    test('--strict passes a clean skill', () async {
      final result = await run(
          [fixture('excellent/pdf-form-filler'), '--strict', '--quiet']);
      expect(result.code, exitOk);
    });

    test('bad path exits 2 with a clear message, no stack trace', () async {
      final result = await run(['/no/such/path-anywhere']);
      expect(result.code, exitUsage);
      expect(result.err, contains('does not exist'));
      expect(result.err, isNot(contains('#0')));
    });

    test('invalid flag exits 2', () async {
      final result = await run(['--format', 'xml', 'x']);
      expect(result.code, exitUsage);
    });

    test('invalid --min-score exits 2', () async {
      final result = await run(
          [fixture('excellent/pdf-form-filler'), '--min-score', 'high']);
      expect(result.code, exitUsage);
    });

    test('no arguments exits 2 with usage', () async {
      final result = await run([]);
      expect(result.code, exitUsage);
      expect(result.err, contains('Usage'));
    });

    test('folder without a manifest exits 2', () async {
      final result = await run([fixture('robustness/no-manifest-here')]);
      expect(result.code, exitUsage);
      expect(result.err, contains('no skill manifest'));
    });
  });

  group('multi-path scoring', () {
    test('scores two explicit skill folders', () async {
      final result = await run([
        fixture('excellent/pdf-form-filler'),
        fixture('mediocre/spreadsheet-skill'),
        '--no-color',
        '--quiet',
      ]);
      expect(result.code, exitOk);
      expect(result.out, contains('pdf-form-filler'));
      expect(result.out,
          contains('csv-to-xlsx')); // frontmatter name of spreadsheet-skill
      final lines = result.out.trim().split('\n');
      expect(lines.length, 2); // one line per skill in quiet mode
    });

    test('deduplicates the same path given twice', () async {
      final result = await run([
        fixture('excellent/pdf-form-filler'),
        fixture('excellent/pdf-form-filler'),
        '--no-color',
        '--quiet',
      ]);
      expect(result.code, exitOk);
      final lines = result.out.trim().split('\n');
      expect(lines.length, 1); // scored once, not twice
    });

    test('deduplicates when a tree path overlaps an explicit child path',
        () async {
      final result = await run([
        fixture('excellent'),
        fixture('excellent/pdf-form-filler'),
        '--no-color',
        '--quiet',
      ]);
      expect(result.code, exitOk);
      final lines = result.out.trim().split('\n');
      expect(lines.where((l) => l.contains('pdf-form-filler')).length, 1);
    });

    test('shows summary for multiple paths', () async {
      final result = await run([
        fixture('excellent/pdf-form-filler'),
        fixture('mediocre/spreadsheet-skill'),
        '--no-color',
      ]);
      expect(result.code, exitOk);
      expect(result.out, contains('skills scored'));
      expect(result.out, contains('average'));
    });

    test('--min-score fails when any score is below threshold', () async {
      final result = await run([
        fixture('excellent/pdf-form-filler'),
        fixture('mediocre/spreadsheet-skill'),
        '--min-score',
        '90',
        '--quiet',
      ]);
      expect(result.code, exitFailedGate);
    });

    test('--format json includes all skills from multiple paths', () async {
      final result = await run([
        fixture('excellent/pdf-form-filler'),
        fixture('mediocre/spreadsheet-skill'),
        '--format',
        'json',
      ]);
      expect(result.code, exitOk);
      final decoded = jsonDecode(result.out) as Map<String, dynamic>;
      expect(decoded['skills'], hasLength(2));
    });

    test('bad path among valid paths warns and continues', () async {
      final result = await run([
        fixture('excellent/pdf-form-filler'),
        '/no/such/path-anywhere',
        '--no-color',
        '--quiet',
      ]);
      expect(result.code, exitOk);
      expect(result.out, contains('pdf-form-filler'));
      expect(result.err, isNotEmpty);
    });

    test('all bad paths exits 2', () async {
      final result = await run(['/no/such/a', '/no/such/b']);
      expect(result.code, exitUsage);
    });
  });

  group('rules and explain commands', () {
    test('rules lists every rule with source guides', () async {
      final result = await run(['rules']);
      expect(result.code, exitOk);
      for (final id in [
        'A1_frontmatter_present',
        'B4_frontloaded_triggers',
        'G2_script_docs',
      ]) {
        expect(result.out, contains(id));
      }
      expect(result.out, contains('Anthropic'));
      expect(result.out, contains('Codex'));
      expect(result.out, contains('Antigravity'));
      expect(result.out, contains('Flutter'));
    });

    test('explain prints rationale, fix, and source', () async {
      final result = await run(['explain', 'B2_description_when']);
      expect(result.code, exitOk);
      expect(result.out, contains('Why:'));
      expect(result.out, contains('Fix:'));
      expect(result.out, contains('Anthropic authoring guide'));
    });

    test('explain accepts a bare rule prefix', () async {
      final result = await run(['explain', 'C1_body_length']);
      expect(result.code, exitOk);
    });

    test('explain with unknown id exits 2', () async {
      final result = await run(['explain', 'Z9_nope']);
      expect(result.code, exitUsage);
    });

    test('explain without id exits 2', () async {
      final result = await run(['explain']);
      expect(result.code, exitUsage);
    });
  });

  group('global flags', () {
    test('--version prints the version', () async {
      final result = await run(['--version']);
      expect(result.code, exitOk);
      expect(result.out.trim(), 'skillscore $packageVersion');
    });

    test('--help prints usage', () async {
      final result = await run(['--help']);
      expect(result.code, exitOk);
      expect(result.out, contains('Usage'));
      expect(result.out, contains('--min-score'));
    });
  });

  group('--fix', () {
    Directory tempSkill(String manifest) {
      final dir = Directory.systemTemp.createTempSync('sk_fix_');
      File('${dir.path}/SKILL.md').writeAsStringSync(manifest);
      return dir;
    }

    test('renames a misspelled key in place and reports it', () async {
      final dir = tempSkill('---\n'
          'name: pdf-form-filler\n'
          'descrption: >-\n'
          '  Fills PDF forms. Use when the user asks to fill a PDF form. '
          'Do not use for scans.\n'
          '---\n# PDF\n## Safety\nNever overwrite.\n');
      try {
        final result = await run([dir.path, '--fix', '--no-color']);
        expect(result.code, isIn([exitOk, exitFailedGate]));
        expect(result.out, contains('Fixed 1 issue'));
        expect(result.out, contains('rename "descrption" to "description"'));
        final fixed = File('${dir.path}/SKILL.md').readAsStringSync();
        expect(fixed, contains('description: >-'));
        expect(fixed, isNot(contains('descrption')));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('is a no-op when nothing is safely fixable', () async {
      final dir = tempSkill('---\n'
          'name: pdf-form-filler\n'
          'description: >-\n'
          '  Fills PDF forms. Use when the user asks to fill a PDF form. '
          'Do not use for scans.\n'
          '---\n# PDF\n## Safety\nNever overwrite.\n');
      try {
        final before = File('${dir.path}/SKILL.md').readAsStringSync();
        final result = await run([dir.path, '--fix', '--no-color']);
        expect(result.out, isNot(contains('Fixed')));
        expect(File('${dir.path}/SKILL.md').readAsStringSync(), before);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('does not touch an unsuggestable unknown key', () async {
      final dir = tempSkill('---\n'
          'name: pdf-form-filler\n'
          'description: >-\n'
          '  Fills PDF forms. Use when the user asks to fill a PDF form. '
          'Do not use for scans.\n'
          'author: someone\n'
          '---\n# PDF\n## Safety\nNever overwrite.\n');
      try {
        final result = await run([dir.path, '--fix', '--no-color']);
        expect(result.out, isNot(contains('Fixed')));
        expect(File('${dir.path}/SKILL.md').readAsStringSync(),
            contains('author: someone'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('--baseline', () {
    // A skill with several findings and a low score.
    const weak = '---\n'
        'name: csv-to-xlsx\n'
        'description: A spreadsheet helper that converts CSV into XLSX.\n'
        '---\n\n# CSV to XLSX\n\nCSV is a widely used data format.\n';

    Directory tempSkills(String manifest) {
      final dir = Directory.systemTemp.createTempSync('sk_base_');
      Directory('${dir.path}/skills/weak').createSync(recursive: true);
      File('${dir.path}/skills/weak/SKILL.md').writeAsStringSync(manifest);
      return dir;
    }

    test('bootstraps a baseline and does not fail on the backlog', () async {
      final dir = tempSkills(weak);
      try {
        final base = '${dir.path}/base.json';
        final result = await run([
          '${dir.path}/skills',
          '--baseline',
          base,
          '--strict',
          '--no-color'
        ]);
        expect(result.code, exitOk, reason: result.out + result.err);
        expect(result.out, contains('Wrote baseline'));
        expect(File(base).existsSync(), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('a clean re-run against the baseline passes even with --strict',
        () async {
      final dir = tempSkills(weak);
      try {
        final base = '${dir.path}/base.json';
        await run(['${dir.path}/skills', '--baseline', base, '--no-color']);
        final result = await run([
          '${dir.path}/skills',
          '--baseline',
          base,
          '--strict',
          '--no-color'
        ]);
        expect(result.code, exitOk);
        expect(result.out, contains('0 new'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('a new finding fails the gate', () async {
      final dir = tempSkills(weak);
      try {
        final base = '${dir.path}/base.json';
        await run(['${dir.path}/skills', '--baseline', base, '--no-color']);
        // Introduce a backslash path: a new F2 finding.
        File('${dir.path}/skills/weak/SKILL.md')
            .writeAsStringSync('${weak}See C:\\data\\out.xlsx.\n');
        final result =
            await run(['${dir.path}/skills', '--baseline', base, '--no-color']);
        expect(result.code, exitFailedGate);
        expect(result.out, contains('new'));
        expect(result.out, contains('F2_forward_slashes'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('--update-baseline re-accepts the current findings', () async {
      final dir = tempSkills(weak);
      try {
        final base = '${dir.path}/base.json';
        await run(['${dir.path}/skills', '--baseline', base, '--no-color']);
        File('${dir.path}/skills/weak/SKILL.md')
            .writeAsStringSync('${weak}See C:\\data\\out.xlsx.\n');
        final updated = await run([
          '${dir.path}/skills',
          '--baseline',
          base,
          '--update-baseline',
          '--no-color',
        ]);
        expect(updated.code, exitOk);
        final after =
            await run(['${dir.path}/skills', '--baseline', base, '--no-color']);
        expect(after.code, exitOk);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('--update-baseline without --baseline is a usage error', () async {
      final result = await run(
          [fixture('excellent/pdf-form-filler'), '--update-baseline']);
      expect(result.code, exitUsage);
      expect(result.err, contains('requires --baseline'));
    });
  });

  group('conflicts command', () {
    Directory twoPdfSkills() {
      final dir = Directory.systemTemp.createTempSync('sk_conf_');
      Directory('${dir.path}/a').createSync();
      Directory('${dir.path}/b').createSync();
      Directory('${dir.path}/c').createSync();
      File('${dir.path}/a/SKILL.md').writeAsStringSync('---\n'
          'name: pdf-filler\n'
          'description: Fills PDF forms. Use when the user asks to fill a PDF form with data.\n'
          '---\n# a\n');
      File('${dir.path}/b/SKILL.md').writeAsStringSync('---\n'
          'name: pdf-writer\n'
          'description: Writes PDF forms. Use when the user wants to fill a PDF form from data.\n'
          '---\n# b\n');
      File('${dir.path}/c/SKILL.md').writeAsStringSync('---\n'
          'name: weather\n'
          'description: Reports the weather. Use when the user asks about rain today.\n'
          '---\n# c\n');
      return dir;
    }

    test('reports an overlapping pair and exits 0 (advisory)', () async {
      final dir = twoPdfSkills();
      try {
        final result = await run(['conflicts', dir.path, '--no-color']);
        expect(result.code, exitOk);
        expect(result.out, contains('overlapping'));
        expect(result.out, contains('pdf-filler'));
        expect(result.out, contains('pdf-writer'));
        expect(result.out, contains('shared triggers'));
        expect(result.out, isNot(contains('weather')));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('--max-overlap gates the exit code', () async {
      final dir = twoPdfSkills();
      try {
        final result = await run(
            ['conflicts', dir.path, '--max-overlap', '0.5', '--no-color']);
        expect(result.code, exitFailedGate);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('--format json emits parseable conflicts', () async {
      final dir = twoPdfSkills();
      try {
        final result = await run(['conflicts', dir.path, '--format', 'json']);
        expect(result.code, exitOk);
        final decoded = jsonDecode(result.out) as Map<String, dynamic>;
        expect(decoded['skillCount'], 3);
        expect(decoded['conflicts'], hasLength(1));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('no path is a usage error', () async {
      final result = await run(['conflicts']);
      expect(result.code, exitUsage);
      expect(result.err, contains('needs one or more paths'));
    });

    test('invalid --max-overlap is a usage error', () async {
      final result =
          await run(['conflicts', fixture(''), '--max-overlap', '5']);
      expect(result.code, exitUsage);
    });

    test('a single skill reports nothing to compare', () async {
      final result = await run(
          ['conflicts', fixture('excellent/pdf-form-filler'), '--no-color']);
      expect(result.code, exitOk);
      expect(result.out, contains('at least two'));
    });
  });
}
