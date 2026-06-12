// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('F1_time_sensitive', () {
    final rule = TimeSensitiveRule();
    test('passes timeless instructions', () {
      expect(
          evaluate(rule, manifestWith(body: 'Use the v2 API for uploads.'))
              .points,
          4);
    });
    test('flags date-anchored statements', () {
      for (final body in [
        'Before August 2025, use the legacy endpoint.',
        'As of 2024 use the old API.',
      ]) {
        final result = evaluate(rule, manifestWith(body: body));
        expect(result.points, 0, reason: body);
        expect(result.findings, isNotEmpty);
      }
    });
    test('allows dated notes inside a details block', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: '<details>\n<summary>Old patterns</summary>\n'
                  'As of 2024 use the old API.\n</details>'));
      expect(result.points, 4);
    });
  });

  group('F2_forward_slashes', () {
    final rule = ForwardSlashesRule();
    test('passes forward-slash paths', () {
      expect(
          evaluate(rule, manifestWith(body: 'Run scripts/run.py today.'))
              .points,
          3);
    });
    test('flags drive-letter paths', () {
      final result = evaluate(
          rule, manifestWith(body: r'Logs are in C:\skills\logs now.'));
      expect(result.points, 0);
    });
    test('flags backslash file paths', () {
      final result =
          evaluate(rule, manifestWith(body: r'Run scripts\run.py today.'));
      expect(result.points, 0);
    });
  });

  group('F3_consistent_terminology', () {
    final rule = ConsistentTerminologyRule();
    test('passes consistent terminology', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: 'Call the endpoint, then call the endpoint again.'));
      expect(result.points, 3);
    });
    test('flags mixed synonyms used repeatedly', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: 'Call the endpoint. The endpoint returns JSON. '
                  'Each route is listed in the route table.'));
      expect(result.points, 0);
      expect(result.findings.single.message, contains('endpoint / route'));
    });
    test('one stray synonym is not flagged (conservative)', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: 'Call the endpoint. The endpoint returns JSON via '
                  'one route.'));
      expect(result.points, 3);
    });
  });
}
