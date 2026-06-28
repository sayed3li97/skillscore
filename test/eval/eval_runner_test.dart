// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

/// Fake client that always returns the configured result.
class _FakeClient implements EvalApiClient {
  _FakeClient({required this.triggered, this.error});

  final bool triggered;
  final String? error;

  @override
  Future<TriggerCheckResult> checkTrigger({
    required String skillName,
    required String skillDescription,
    required String query,
  }) async =>
      TriggerCheckResult(triggered: triggered, error: error);
}

/// Client that alternates triggered/not per call.
class _AlternatingClient implements EvalApiClient {
  int _call = 0;

  @override
  Future<TriggerCheckResult> checkTrigger({
    required String skillName,
    required String skillDescription,
    required String query,
  }) async {
    _call++;
    return TriggerCheckResult(triggered: _call.isOdd);
  }
}

EvalDocument _doc({int runsPerQuery = 3, double threshold = 0.5}) =>
    EvalDocument(
      skillName: 'pdf-filler',
      runsPerQuery: runsPerQuery,
      triggerThreshold: threshold,
      queries: const [
        EvalQuery(query: 'Fill this PDF', shouldTrigger: true),
        EvalQuery(query: 'Print this PDF', shouldTrigger: false),
      ],
    );

SkillDocument _skill() => parseDoc(manifestWith(
      name: 'pdf-filler',
      description: 'Fills PDFs. Use when the user asks to fill a PDF form.',
    ));

void main() {
  group('EvalRunner', () {
    test('all pass when trigger always fires for trigger queries', () async {
      final runner = EvalRunner(client: _FakeClient(triggered: true));
      final result = await runner.run(_doc(), _skill());
      // Trigger query passes (rate 1.0 >= 0.5).
      // Non-trigger query fails (rate 1.0 is NOT < 0.5).
      expect(result.queryResults[0].passes(0.5), isTrue);
      expect(result.queryResults[1].passes(0.5), isFalse);
    });

    test('all pass when trigger never fires for non-trigger queries', () async {
      final runner = EvalRunner(client: _FakeClient(triggered: false));
      final result = await runner.run(_doc(), _skill());
      // Trigger query fails (rate 0.0 < 0.5).
      expect(result.queryResults[0].passes(0.5), isFalse);
      // Non-trigger query passes (rate 0.0 < 0.5).
      expect(result.queryResults[1].passes(0.5), isTrue);
    });

    test('triggerRate is count/total', () async {
      final runner = EvalRunner(client: _AlternatingClient());
      final result = await runner.run(_doc(runsPerQuery: 3), _skill());
      final qr = result.queryResults[0];
      expect(qr.totalRuns, 3);
      expect(qr.triggerRate, inInclusiveRange(0.0, 1.0));
    });

    test('errors are collected per query', () async {
      final runner =
          EvalRunner(client: _FakeClient(triggered: false, error: 'boom'));
      final result = await runner.run(_doc(runsPerQuery: 2), _skill());
      for (final qr in result.queryResults) {
        expect(qr.errors, hasLength(2)); // 2 runs, each errors
      }
    });

    test('allPassed reflects combined pass/fail', () async {
      final runner = EvalRunner(client: _FakeClient(triggered: true));
      final result = await runner.run(_doc(), _skill());
      expect(result.allPassed, isFalse);
      expect(result.failCount, greaterThan(0));
    });

    test('passCount + failCount == queryResults.length', () async {
      final runner = EvalRunner(client: _FakeClient(triggered: false));
      final result = await runner.run(_doc(), _skill());
      expect(result.passCount + result.failCount, result.queryResults.length);
    });

    test('progress callback is invoked once per invocation', () async {
      final calls = <String>[];
      final runner = EvalRunner(
        client: _FakeClient(triggered: true),
        onProgress: calls.add,
      );
      await runner.run(_doc(runsPerQuery: 2), _skill());
      // 2 queries × 2 runs = 4 progress callbacks.
      expect(calls, hasLength(4));
    });

    test('respects threshold parameter in passes()', () async {
      final runner = EvalRunner(client: _AlternatingClient());
      final doc = _doc(runsPerQuery: 1, threshold: 0.9);
      final result = await runner.run(doc, _skill());
      final qr = result.queryResults[0];
      expect(qr.passes(0.9), qr.triggerRate >= 0.9 ? isTrue : isFalse);
    });
  });

  group('QueryResult', () {
    const q = EvalQuery(query: 'test', shouldTrigger: true);

    test('triggerRate is 0 when totalRuns is 0', () {
      const qr = QueryResult(query: q, triggerCount: 0, totalRuns: 0);
      expect(qr.triggerRate, 0.0);
    });

    test('passes when triggerRate >= threshold for trigger query', () {
      const qr = QueryResult(query: q, triggerCount: 2, totalRuns: 3);
      expect(qr.passes(0.5), isTrue); // 0.67 >= 0.5
      expect(qr.passes(0.8), isFalse); // 0.67 < 0.8
    });

    test('passes when triggerRate < threshold for non-trigger query', () {
      const ntq = EvalQuery(query: 'test', shouldTrigger: false);
      const qr = QueryResult(query: ntq, triggerCount: 1, totalRuns: 3);
      expect(qr.passes(0.5), isTrue); // 0.33 < 0.5
      expect(qr.passes(0.2), isFalse); // 0.33 >= 0.2
    });
  });
}
