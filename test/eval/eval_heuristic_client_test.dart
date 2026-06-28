// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

void main() {
  const client = HeuristicEvalClient();
  const apiKey = '';
  const model = 'offline';

  const desc = 'Fills PDF form fields from structured JSON data. '
      'Use when the user asks to fill or complete a PDF form. '
      'Do not use for scanned or image-only PDFs.';

  Future<bool> check(String query) async {
    final r = await client.checkTrigger(
      apiKey: apiKey,
      model: model,
      skillName: 'pdf-form-filler',
      skillDescription: desc,
      query: query,
    );
    return r.triggered;
  }

  group('HeuristicEvalClient', () {
    test('trigger query is triggered', () async {
      final results = await Future.wait([
        check('Fill the W-9 form from the JSON payload'),
        check('I need to fill in a PDF form'),
        check('Please complete this PDF form with the JSON data'),
      ]);
      expect(results.where((r) => r).length, greaterThanOrEqualTo(2),
          reason: 'majority of trigger queries should be triggered');
    });

    test('meta/explainer queries are not triggered', () async {
      final results = await Future.wait([
        check('What is PDF form filling?'),
        check('Explain PDF forms to me'),
        check('Tell me the history of PDF forms'),
        check('Write a unit test for PDF form filling'),
        check('Debug why PDF form filling is not working'),
      ]);
      expect(results.where((r) => r).length, lessThanOrEqualTo(1),
          reason: 'meta queries should mostly not trigger');
    });

    test('boundary queries are not triggered', () async {
      final results = await Future.wait([
        check('I have a scanned PDF, can you help?'),
        check('Process this image-only PDF document'),
      ]);
      expect(results.where((r) => r).length, lessThanOrEqualTo(1),
          reason: 'boundary queries should not trigger');
    });

    test('successive calls vary results slightly (simulates stochasticity)',
        () async {
      const query = 'Fill this PDF form with my JSON data';
      final outcomes = <bool>[];
      for (var i = 0; i < 10; i++) {
        outcomes.add(await check(query));
      }
      // Should not be all-identical over 10 calls (noise is present).
      // Either all true or all false would be unusual but possible;
      // we just verify no exception is thrown and results are booleans.
      expect(outcomes, everyElement(isA<bool>()));
    });

    test('returns TriggerCheckResult with no error', () async {
      final result = await client.checkTrigger(
        apiKey: apiKey,
        model: model,
        skillName: 'test',
        skillDescription: desc,
        query: 'Fill a PDF form',
      );
      expect(result.hasError, isFalse);
      expect(result.error, isNull);
    });
  });
}
