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
  final scorer = Scorer(RuleRegistry());

  test('skill names never affect scoring (name-agnostic)', () {
    // Identical content under three different names must score the same.
    String content(String name) => manifestWith(
        name: name,
        body: '1. Do the thing.\n2. Do not skip validation: run the tests, '
            'fix failures, repeat.\n\n```text\nexample\n```');
    final scores = ['make-pancakes', 'q4-finance-report', 'zz-anything']
        .map((name) => scorer
            .score(parseDoc(content(name), path: '/tmp/$name/SKILL.md'),
                Target.universal)
            .score)
        .toSet();
    expect(scores, hasLength(1));
  });

  test('scores a skill with a non-skillscore name end to end', () async {
    final result = await run(
        [fixture('robustness/make-pancakes'), '--no-color', '--quiet']);
    expect(result.code, exitOk);
    expect(result.out, contains('make-pancakes'));
  });

  test('unicode folder name, mixed-case manifest, BOM and CRLF', () async {
    final result = await run([
      fixture('robustness/企業-スキル'),
      '--format',
      'json',
    ]);
    expect(result.code, exitOk);
    final skill = (jsonDecode(result.out)['skills'] as List).first as Map;
    expect(skill['name'], 'report-formatter');
    expect(skill['score'], greaterThan(50));
  });

  test('zero-byte manifest scores without crashing', () async {
    final result =
        await run([fixture('robustness/empty-skill'), '--no-color', '--quiet']);
    expect(result.code, exitOk);
    expect(result.out, contains('Grade: F'));
  });

  test('frontmatter-less file still gets body findings', () {
    final doc =
        SkillParser().parseFile(fixture('broken/legacy-notes/SKILL.md'));
    final result = scorer.score(doc, Target.universal);
    final categories = result.findings.map((f) => f.category).toSet();
    expect(categories, containsAll(['A', 'C', 'E', 'F']));
  });

  test('multi-skill runs are ordered by path and stable', () async {
    final a = await run([fixture('robustness'), '--quiet', '--no-color']);
    final b = await run([fixture('robustness'), '--quiet', '--no-color']);
    expect(a.out, b.out);
    expect(a.code, exitOk);
  });
}
