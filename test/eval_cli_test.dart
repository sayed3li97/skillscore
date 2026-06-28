// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

Future<(int, String, String)> run(List<String> args,
    {Map<String, String>? env}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(args, out: out, err: err);
  return (code, out.toString(), err.toString());
}

void main() {
  group('eval subcommand routing', () {
    test('unknown subcommand exits 2', () async {
      final (code, _, err) = await run(['eval', 'frobnicate']);
      expect(code, exitUsage);
      expect(err, contains('unknown eval subcommand'));
    });

    test('bare eval without subcommand exits 2', () async {
      final (code, _, err) = await run(['eval']);
      expect(code, exitUsage);
      expect(err, contains('subcommand'));
    });
  });

  group('eval init', () {
    test('no path argument exits 2', () async {
      final (code, _, err) = await run(['eval', 'init']);
      expect(code, exitUsage);
      expect(err, contains('skill path'));
    });

    test('creates evals.json next to SKILL.md', () async {
      await inTempSkill({'SKILL.md': _excellentManifest}, (root) async {
        final (code, out, err) = await run(['eval', 'init', root]);
        expect(err, isEmpty, reason: 'stderr: $err');
        expect(code, exitOk);
        expect(File('$root/evals.json').existsSync(), isTrue);
        expect(out, contains('evals.json'));
      });
    });

    test('generated evals.json is valid JSON parseable by EvalParser',
        () async {
      await inTempSkill({'SKILL.md': _excellentManifest}, (root) async {
        await run(['eval', 'init', root]);
        final content = File('$root/evals.json').readAsStringSync();
        final result = const EvalParser().parse(content);
        expect(result.isValid, isTrue, reason: result.errors.join('; '));
      });
    });

    test('exits 2 if evals.json already exists', () async {
      await inTempSkill({
        'SKILL.md': _excellentManifest,
        'evals.json': '{}',
      }, (root) async {
        final (code, _, err) = await run(['eval', 'init', root]);
        expect(code, exitUsage);
        expect(err, contains('already exists'));
      });
    });

    test('exits 2 if no SKILL.md found', () async {
      await inTempSkill({'README.md': '# nothing'}, (root) async {
        final (code, _, err) = await run(['eval', 'init', root]);
        expect(code, exitUsage);
        expect(err, contains('no skill manifest'));
      });
    });
  });

  group('eval validate', () {
    test('validates a well-formed evals.json', () async {
      await inTempSkill({
        'SKILL.md': _excellentManifest,
        'evals.json': _validEvalsJson,
      }, (root) async {
        final (code, out, err) = await run(['eval', 'validate', root]);
        expect(code, exitOk, reason: 'stderr: $err');
        expect(out, contains('OK'));
        expect(out, contains('queries'));
      });
    });

    test('exits 2 for missing evals.json', () async {
      await inTempSkill({'SKILL.md': _excellentManifest}, (root) async {
        final (code, _, err) = await run(['eval', 'validate', root]);
        expect(code, exitUsage);
        expect(err, contains('evals.json not found'));
      });
    });

    test('exits 2 for malformed evals.json', () async {
      await inTempSkill({
        'SKILL.md': _excellentManifest,
        'evals.json': '{"skill": "x"}',
      }, (root) async {
        final (code, _, err) = await run(['eval', 'validate', root]);
        expect(code, exitUsage);
        expect(err, contains('error'));
      });
    });

    test('no path exits 2', () async {
      final (code, _, err) = await run(['eval', 'validate']);
      expect(code, exitUsage);
    });
  });

  group('eval run', () {
    test('runs offline and produces a scored report', () async {
      await inTempSkill({
        'SKILL.md': _excellentManifest,
        'evals.json': _validEvalsJson,
      }, (root) async {
        final (code, out, err) = await run(['eval', 'run', root]);
        // The command must finish cleanly (exit 0 = all pass, exit 1 = some
        // fail — both are valid outcomes for offline heuristic scoring).
        expect(code, isIn([exitOk, exitFailedGate]),
            reason: 'stderr: $err');
        expect(out, contains('passed'));
        expect(out, contains('eval'));
      });
    });

    test('no path exits 2', () async {
      final (code, _, err) = await run(['eval', 'run']);
      expect(code, exitUsage);
    });

    test('missing evals.json exits 2', () async {
      await inTempSkill({'SKILL.md': _excellentManifest}, (root) async {
        final (code, _, err) = await run(['eval', 'run', root]);
        expect(code, exitUsage);
        expect(err, contains('evals.json'));
      });
    });

    test('json format produces machine-readable output', () async {
      await inTempSkill({
        'SKILL.md': _excellentManifest,
        'evals.json': _validEvalsJson,
      }, (root) async {
        final (_, out, _) = await run(['--format', 'json', 'eval', 'run', root]);
        expect(() => out.trim(), returnsNormally);
        expect(out, contains('"skill"'));
        expect(out, contains('"passed"'));
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _excellentManifest = '''
---
name: pdf-form-filler
description: >-
  Fills PDF form fields from structured JSON data. Use when the user asks
  to fill or complete a PDF form programmatically.
  Do not use for scanned or image-only PDFs.
---

# PDF form filler

Fill AcroForm fields in an existing PDF from a JSON mapping.
''';

const _validEvalsJson = '''
{
  "skill": "pdf-form-filler",
  "version": 1,
  "runs_per_query": 1,
  "trigger_threshold": 0.5,
  "queries": [
    {"id": "t01", "query": "Fill this PDF form with my data", "should_trigger": true},
    {"id": "t02", "query": "Complete the form fields in this PDF", "should_trigger": true},
    {"id": "n01", "query": "Print this document", "should_trigger": false},
    {"id": "n02", "query": "Convert this PDF to Word", "should_trigger": false}
  ]
}
''';

// Override inTempSkill to support async callbacks in tests.
Future<T> inTempSkill<T>(
    Map<String, String> files, Future<T> Function(String root) fn) async {
  final dir = Directory.systemTemp.createTempSync('skillscore_eval_test_');
  try {
    files.forEach((rel, content) {
      final file = File('${dir.path}/$rel');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    });
    return await fn(dir.path);
  } finally {
    dir.deleteSync(recursive: true);
  }
}
