// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('B1_description_what', () {
    final rule = DescriptionWhatRule();
    test('passes when opening with an action verb', () {
      final result = evaluate(
          rule, manifestWith(description: 'Generates invoices from JSON.'));
      expect(result.points, 6);
    });
    test('awards partial credit when the verb is not first', () {
      final result = evaluate(
          rule, manifestWith(description: 'A helper that generates invoices.'));
      expect(result.points, 3);
      expect(result.findings, hasLength(1));
    });
    test('fails without any action verb', () {
      final result = evaluate(
          rule, manifestWith(description: 'For all your invoice needs.'));
      expect(result.points, 0);
    });
    test('awards 0 silently when description is missing', () {
      final result = evaluate(rule, '---\nname: x\n---\n');
      expect(result.points, 0);
      expect(result.findings, isEmpty);
    });
  });

  group('B2_description_when', () {
    final rule = DescriptionWhenRule();
    test('passes with a "use when" trigger', () {
      final result = evaluate(rule,
          manifestWith(description: 'Scores skills. Use when reviewing.'));
      expect(result.points, 6);
    });
    test('passes with "when the user" phrasing', () {
      final result = evaluate(
          rule,
          manifestWith(
              description: 'Scores skills when the user asks for review.'));
      expect(result.points, 6);
    });
    test('fails without trigger phrasing', () {
      final result = evaluate(
          rule, manifestWith(description: 'Scores agent skills accurately.'));
      expect(result.points, 0);
    });
  });

  group('B3_third_person', () {
    final rule = ThirdPersonRule();
    test('passes third-person descriptions', () {
      final result = evaluate(rule,
          manifestWith(description: 'Converts CSV files to XLSX workbooks.'));
      expect(result.points, 5);
    });
    test('flags "I can"', () {
      final result =
          evaluate(rule, manifestWith(description: 'I can convert CSV files.'));
      expect(result.points, 0);
      expect(result.findings.single.message, contains('"I"'));
    });
    test('flags "you can"', () {
      final result = evaluate(
          rule, manifestWith(description: 'With this you can convert files.'));
      expect(result.points, 0);
    });
    test('flags "we"', () {
      final result = evaluate(
          rule, manifestWith(description: 'We convert CSV files here.'));
      expect(result.points, 0);
    });
  });

  group('B4_frontloaded_triggers', () {
    final rule = FrontloadedTriggersRule();
    test('is active only for codex and universal', () {
      expect(rule.targets, {Target.codex, Target.universal});
    });
    test('passes a concrete front-loaded description', () {
      final result = evaluate(rule,
          manifestWith(description: 'Converts CSV to XLSX with styling.'));
      expect(result.points, 4);
    });
    test('fails filler openings', () {
      for (final filler in [
        'A tool that helps with spreadsheets and data.',
        'This skill helps with converting files.',
        'Designed to make conversions easier for everyone.',
      ]) {
        final result = evaluate(rule, manifestWith(description: filler));
        expect(result.points, 0, reason: filler);
      }
    });
    test('ignores filler beyond the first 60 characters', () {
      final head = 'Converts CSV files to styled XLSX workbooks quickly';
      final result = evaluate(rule,
          manifestWith(description: '$head and also helps with cleanup.'));
      expect(result.points, 4);
    });
  });

  group('B5_boundary_clause', () {
    final rule = BoundaryClauseRule();
    test('is active only for antigravity and universal', () {
      expect(rule.targets, {Target.antigravity, Target.universal});
    });
    test('passes with a "Do not use" boundary', () {
      final result = evaluate(
          rule,
          manifestWith(
              description: 'Fills PDFs. Do not use for scanned documents.'));
      expect(result.points, 4);
    });
    test('fails without any boundary', () {
      final result =
          evaluate(rule, manifestWith(description: 'Fills PDF forms.'));
      expect(result.points, 0);
    });
    test('is WARNING on antigravity, INFO elsewhere', () {
      final registry = RuleRegistry();
      final r = registry.byId('B5_boundary_clause')!;
      expect(
          registry.effectiveSeverity(r, Target.antigravity), Severity.warning);
      expect(registry.effectiveSeverity(r, Target.universal), Severity.info);
    });
  });

  group('B6_description_truncation', () {
    final rule = DescriptionTruncationRule();
    test('is active only for claude and universal', () {
      expect(rule.targets, {Target.claude, Target.universal});
    });
    test('passes when description is exactly 250 characters', () {
      final desc = 'A' * 250;
      final result = evaluate(rule, manifestWith(description: desc));
      expect(result.points, 3);
      expect(result.findings, isEmpty);
    });
    test('passes when description is under 250 characters', () {
      final result = evaluate(
          rule,
          manifestWith(
              description:
                  'Generates reports. Use when the user asks for a summary.'));
      expect(result.points, 3);
    });
    test('fails when description exceeds 250 characters', () {
      final desc = 'Generates detailed quarterly financial reports including '
          'revenue, expenses, headcount, and margin breakdowns. '
          'Use when the user asks for a quarterly summary, revenue analysis, '
          'or financial breakdown by department or product line. '
          'Do not use for real-time dashboards or live feeds.';
      assert(desc.length > 250, 'test fixture must exceed 250 chars');
      final result = evaluate(rule, manifestWith(description: desc));
      expect(result.points, 0);
      expect(result.findings, hasLength(1));
      expect(result.findings.single.message, contains('250'));
    });
    test('awards 0 silently when description is missing', () {
      final result = evaluate(rule, '---\nname: x\n---\n');
      expect(result.points, 0);
      expect(result.findings, isEmpty);
    });
    test('is not active for codex or antigravity', () {
      expect(rule.targets.contains(Target.codex), isFalse);
      expect(rule.targets.contains(Target.antigravity), isFalse);
    });
  });
}
