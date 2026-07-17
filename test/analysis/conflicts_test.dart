// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

SkillEntry _e(String name, String description) =>
    SkillEntry(name: name, path: '$name/SKILL.md', description: description);

void main() {
  group('skill_terms', () {
    test('trigger surface pulls content terms from use-when and first sentence',
        () {
      final surface = triggerSurface(
          'Fills PDF forms. Use when the user asks to fill a PDF form.');
      expect(surface, containsAll(['pdf', 'form', 'fill']));
      expect(surface, isNot(contains('use'))); // stop word
    });

    test('exclusive boundary terms exclude those in the trigger surface', () {
      final boundary = exclusiveBoundaryTerms(
          'Fills PDF forms. Do not use for scanned images.');
      expect(boundary, contains('image')); // boundary-only term
      expect(boundary, isNot(contains('pdf'))); // shared with trigger surface
      expect(boundary, isNot(contains('form')));
    });
  });

  group('ConflictDetector', () {
    test('flags two skills that trigger on the same requests', () {
      final conflicts = const ConflictDetector().analyze([
        _e('pdf-a',
            'Fills PDF forms. Use when the user asks to fill a PDF form with data.'),
        _e('pdf-b',
            'Writes PDF forms. Use when the user wants to fill a PDF form from data.'),
        _e('weather',
            'Reports the weather. Use when the user asks about rain today.'),
      ]);
      expect(conflicts, hasLength(1));
      expect({conflicts.single.a.name, conflicts.single.b.name},
          {'pdf-a', 'pdf-b'});
      expect(conflicts.single.shared, containsAll(['pdf', 'form']));
      expect(conflicts.single.overlap, greaterThanOrEqualTo(0.5));
    });

    test('does not flag unrelated skills', () {
      final conflicts = const ConflictDetector().analyze([
        _e('csv',
            'Converts CSV to XLSX. Use when the user makes a spreadsheet.'),
        _e('email', 'Sends email. Use when the user wants to email someone.'),
      ]);
      expect(conflicts, isEmpty);
    });

    test('needs at least minShared terms to flag a pair', () {
      // Share only "report" (1 term) -> below the default minShared of 2.
      final conflicts = const ConflictDetector().analyze([
        _e('a', 'Reports weather. Use when the user asks about rain.'),
        _e('b', 'Reports stock prices. Use when the user checks a ticker.'),
      ]);
      expect(conflicts, isEmpty);
    });

    test('respects a higher threshold', () {
      // surface a = {fill, pdf, form}; b = {read, pdf, form, image, scan};
      // shared {pdf, form} = 2, overlap 2/3 ~= 0.67.
      final pair = [
        _e('a', 'Fills pdf forms.'),
        _e('b', 'Reads pdf forms images scans.'),
      ];
      expect(const ConflictDetector(threshold: 0.5).analyze(pair), isNotEmpty);
      expect(const ConflictDetector(threshold: 0.95).analyze(pair), isEmpty);
    });

    test('sorts most-overlapping pairs first', () {
      final conflicts = const ConflictDetector(minShared: 1).analyze([
        _e('pdf-a', 'Fills PDF forms. Use when the user fills a PDF form.'),
        _e('pdf-b', 'Writes PDF forms. Use when the user writes a PDF form.'),
        _e('pdf-c',
            'Handles PDF documents and many other office file formats and images.'),
      ]);
      for (var i = 1; i < conflicts.length; i++) {
        expect(conflicts[i - 1].overlap,
            greaterThanOrEqualTo(conflicts[i].overlap));
      }
    });

    test('skips a skill with no description without crashing', () {
      final conflicts = const ConflictDetector().analyze([
        _e('empty', ''),
        _e('pdf', 'Fills PDF forms. Use when the user fills a PDF form.'),
      ]);
      expect(conflicts, isEmpty);
    });

    test('reports whether both skills already carry a boundary', () {
      final conflicts = const ConflictDetector().analyze([
        _e('pdf-a',
            'Fills PDF forms. Use when the user fills a PDF form. Do not use for scanned images.'),
        _e('pdf-b',
            'Writes PDF forms. Use when the user writes a PDF form. Do not use for spreadsheets.'),
      ]);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.bothBounded, isTrue);
    });
  });
}
