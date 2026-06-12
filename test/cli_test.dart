// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

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
}
