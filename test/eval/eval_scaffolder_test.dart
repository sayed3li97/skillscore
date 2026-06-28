// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  const scaffolder = EvalScaffolder();

  SkillDocument makeSkill({String? description, String? name}) {
    return parseDoc(manifestWith(
      name: name ?? 'pdf-form-filler',
      description: description ??
          'Fills PDF form fields from structured JSON data. '
              'Use when the user asks to fill or complete a PDF form. '
              'Do not use for scanned or image-only PDFs.',
    ));
  }

  group('EvalScaffolder.scaffold', () {
    test('produces a valid EvalDocument', () {
      final parseResult = const EvalParser().parse(
        EvalScaffolder().generate(makeSkill()),
      );
      expect(parseResult.isValid, isTrue,
          reason: parseResult.errors.join('; '));
    });

    test('uses the skill name as the document skill name', () {
      final doc = scaffolder.scaffold(makeSkill(name: 'my-skill'));
      expect(doc.skillName, 'my-skill');
    });

    test('generates both trigger and non-trigger queries', () {
      final doc = scaffolder.scaffold(makeSkill());
      expect(doc.triggerQueries, isNotEmpty);
      expect(doc.nonTriggerQueries, isNotEmpty);
    });

    test('generates at least 5 trigger queries', () {
      final doc = scaffolder.scaffold(makeSkill());
      expect(doc.triggerQueries.length, greaterThanOrEqualTo(5));
    });

    test('generates at least 5 non-trigger queries', () {
      final doc = scaffolder.scaffold(makeSkill());
      expect(doc.nonTriggerQueries.length, greaterThanOrEqualTo(5));
    });

    test('all queries are non-empty strings', () {
      final doc = scaffolder.scaffold(makeSkill());
      for (final q in doc.queries) {
        expect(q.query.trim(), isNotEmpty, reason: 'empty query found');
      }
    });

    test('trigger queries have shouldTrigger == true', () {
      final doc = scaffolder.scaffold(makeSkill());
      for (final q in doc.triggerQueries) {
        expect(q.shouldTrigger, isTrue);
      }
    });

    test('non-trigger queries have shouldTrigger == false', () {
      final doc = scaffolder.scaffold(makeSkill());
      for (final q in doc.nonTriggerQueries) {
        expect(q.shouldTrigger, isFalse);
      }
    });

    test('assigns stable ids starting with t/n prefix', () {
      final doc = scaffolder.scaffold(makeSkill());
      final triggerIds = doc.triggerQueries.map((q) => q.id ?? '');
      final nonTriggerIds = doc.nonTriggerQueries.map((q) => q.id ?? '');
      expect(triggerIds.every((id) => id.startsWith('t')), isTrue);
      expect(nonTriggerIds.every((id) => id.startsWith('n')), isTrue);
    });

    test('works with a minimal description (no trigger clause)', () {
      final doc = scaffolder
          .scaffold(makeSkill(description: 'Generates reports on demand.'));
      expect(doc.queries, isNotEmpty);
    });

    test('works with a description that has no action verb', () {
      final doc = scaffolder
          .scaffold(makeSkill(description: 'A helper for PDF forms.'));
      expect(doc.queries, isNotEmpty);
    });

    test('uses default config values', () {
      final doc = scaffolder.scaffold(makeSkill());
      expect(doc.runsPerQuery, defaultRunsPerQuery);
      expect(doc.triggerThreshold, defaultTriggerThreshold);
      expect(doc.model, defaultEvalModel);
    });
  });

  group('EvalScaffolder.generate', () {
    test('returns valid JSON accepted by EvalParser', () {
      final json = scaffolder.generate(makeSkill());
      final result = const EvalParser().parse(json);
      expect(result.isValid, isTrue, reason: result.errors.join('; '));
    });

    test('output is indented JSON (human-readable)', () {
      final json = scaffolder.generate(makeSkill());
      expect(json, contains('\n'));
      expect(json, contains('  '));
    });
  });
}
