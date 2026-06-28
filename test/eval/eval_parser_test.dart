// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

void main() {
  const parser = EvalParser();

  group('valid evals.json', () {
    const minimal = '''
{
  "skill": "pdf-form-filler",
  "version": 1,
  "queries": [
    {"query": "Fill this PDF form", "should_trigger": true},
    {"query": "Print the document", "should_trigger": false}
  ]
}''';

    test('parses a minimal valid file', () {
      final result = parser.parse(minimal);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      // 2-query suite produces an advisory warning, not a hard error.
      expect(result.warnings, isNotEmpty);
      final doc = result.document!;
      expect(doc.skillName, 'pdf-form-filler');
      expect(doc.version, 1);
      expect(doc.runsPerQuery, defaultRunsPerQuery);
      expect(doc.triggerThreshold, defaultTriggerThreshold);
      expect(doc.model, defaultEvalModel);
      expect(doc.queries, hasLength(2));
    });

    test('honours explicit config values', () {
      const json = '''
{
  "skill": "csv-exporter",
  "version": 1,
  "runs_per_query": 5,
  "trigger_threshold": 0.7,
  "model": "claude-haiku-4-5-20251001",
  "queries": [
    {"id": "t01", "query": "Export CSV", "should_trigger": true},
    {"id": "n01", "query": "Import CSV", "should_trigger": false}
  ]
}''';
      final doc = parser.parse(json).document!;
      expect(doc.runsPerQuery, 5);
      expect(doc.triggerThreshold, 0.7);
      expect(doc.queries.first.id, 't01');
    });

    test('triggerQueries and nonTriggerQueries partition correctly', () {
      const json = '''
{
  "skill": "x",
  "queries": [
    {"query": "A", "should_trigger": true},
    {"query": "B", "should_trigger": false},
    {"query": "C", "should_trigger": true}
  ]
}''';
      final doc = parser.parse(json).document!;
      expect(doc.triggerQueries, hasLength(2));
      expect(doc.nonTriggerQueries, hasLength(1));
    });
  });

  group('validation errors', () {
    test('rejects missing skill field', () {
      final result = parser.parse('{"queries": []}');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('"skill"'));
    });

    test('rejects empty queries array', () {
      final result = parser.parse('{"skill": "x", "queries": []}');
      expect(result.isValid, isFalse);
    });

    test('rejects missing should_trigger', () {
      const json = '{"skill":"x","queries":[{"query":"hi"}]}';
      final result = parser.parse(json);
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('should_trigger'));
    });

    test('rejects empty query string', () {
      const json =
          '{"skill":"x","queries":[{"query":"","should_trigger":true}]}';
      final result = parser.parse(json);
      expect(result.isValid, isFalse);
    });

    test('rejects runs_per_query outside 1..20', () {
      const json = '{"skill":"x","runs_per_query":0,"queries":'
          '[{"query":"A","should_trigger":true},'
          '{"query":"B","should_trigger":false}]}';
      final result = parser.parse(json);
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('runs_per_query'));
    });

    test('rejects trigger_threshold outside 0..1', () {
      const json = '{"skill":"x","trigger_threshold":1.5,"queries":'
          '[{"query":"A","should_trigger":true},'
          '{"query":"B","should_trigger":false}]}';
      final result = parser.parse(json);
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('trigger_threshold'));
    });

    test('warns when only trigger queries present (no non-trigger)', () {
      const json = '{"skill":"x","queries":'
          '[{"query":"A","should_trigger":true},'
          '{"query":"B","should_trigger":true}]}';
      final result = parser.parse(json);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('non-trigger')), isTrue);
    });

    test('warns when only non-trigger queries present', () {
      const json = '{"skill":"x","queries":'
          '[{"query":"A","should_trigger":false}]}';
      final result = parser.parse(json);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('trigger')), isTrue);
    });

    test('rejects invalid JSON', () {
      final result = parser.parse('{broken json}');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('invalid JSON'));
    });

    test('rejects non-object root', () {
      final result = parser.parse('[1, 2, 3]');
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('JSON object'));
    });
  });

  group('round-trip', () {
    test('toJson -> fromJson is stable', () {
      const json = '''
{
  "skill": "pdf-filler",
  "version": 1,
  "runs_per_query": 3,
  "trigger_threshold": 0.5,
  "model": "claude-haiku-4-5-20251001",
  "queries": [
    {"id": "t01", "query": "Fill form", "should_trigger": true},
    {"id": "n01", "query": "Read form", "should_trigger": false}
  ]
}''';
      final doc = parser.parse(json).document!;
      final rebuilt = EvalDocument.fromJson(doc.toJson());
      expect(rebuilt.skillName, doc.skillName);
      expect(rebuilt.runsPerQuery, doc.runsPerQuery);
      expect(rebuilt.queries.length, doc.queries.length);
      expect(rebuilt.queries.first.id, doc.queries.first.id);
    });
  });
}
