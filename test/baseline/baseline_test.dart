// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

Finding _f(String ruleId, {Severity severity = Severity.warning, int? line}) =>
    Finding(
      ruleId: ruleId,
      severity: severity,
      message: 'message for $ruleId',
      fixHint: 'fix',
      sourceGuide: 'Anthropic',
      line: line,
    );

void main() {
  group('Baseline', () {
    test('records gated findings as per-(path, rule) counts', () {
      final b = Baseline.record({
        'a/SKILL.md': [_f('B1'), _f('B2')],
        'b/SKILL.md': [_f('B1')],
      });
      expect(b.total, 3);
      expect(b.counts['a/SKILL.md\tB1'], 1);
      expect(b.counts['b/SKILL.md\tB1'], 1);
    });

    test('ignores info-level findings entirely', () {
      final b = Baseline.record({
        'a/SKILL.md': [_f('C3', severity: Severity.info), _f('B1')],
      });
      expect(b.total, 1);
      expect(b.counts.containsKey('a/SKILL.md\tC3'), isFalse);
    });

    test('reports no new findings when the set is unchanged', () {
      final b = Baseline.record({
        'a/SKILL.md': [_f('B1'), _f('B2')],
      });
      // Same findings on different lines (line is not part of the fingerprint).
      final current = {
        'a/SKILL.md': [_f('B2', line: 99), _f('B1', line: 3)],
      };
      expect(b.newFindings(current), isEmpty);
    });

    test('flags a finding that exceeds the accepted count', () {
      final b = Baseline.record({
        'a/SKILL.md': [_f('B1')],
      });
      final current = {
        'a/SKILL.md': [_f('B1'), _f('B1')], // one more than accepted
      };
      final fresh = b.newFindings(current);
      expect(fresh, hasLength(1));
      expect(fresh.single.ruleId, 'B1');
    });

    test('flags a finding for a rule that was never baselined', () {
      final b = Baseline.record({
        'a/SKILL.md': [_f('B1')],
      });
      final fresh = b.newFindings({
        'a/SKILL.md': [_f('B1'), _f('F2', severity: Severity.error)],
      });
      expect(fresh.map((f) => f.ruleId), ['F2']);
    });

    test('does not gate on new info findings', () {
      final b = Baseline.record({'a/SKILL.md': <Finding>[]});
      final fresh = b.newFindings({
        'a/SKILL.md': [_f('C3', severity: Severity.info)],
      });
      expect(fresh, isEmpty);
    });

    test('serializes to sorted, stable JSON and round-trips', () {
      final b = Baseline.record({
        'z/SKILL.md': [_f('B2')],
        'a/SKILL.md': [_f('B1')],
      });
      final json = b.toJson();
      // Deterministic ordering: a before z.
      expect(json.indexOf('a/SKILL.md'), lessThan(json.indexOf('z/SKILL.md')));
      final parsed = Baseline.parse(json);
      expect(parsed.counts, b.counts);
    });

    test('rejects a malformed baseline document', () {
      expect(() => Baseline.parse('{"nope": 1}'), throwsFormatException);
      expect(() => Baseline.parse('not json'), throwsFormatException);
    });
  });
}
