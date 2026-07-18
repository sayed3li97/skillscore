// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final scorer = Scorer(RuleRegistry());

  group('grading scale', () {
    test('maps scores to letters at the documented boundaries', () {
      expect(gradeFor(100), 'A');
      expect(gradeFor(90), 'A');
      expect(gradeFor(89), 'B');
      expect(gradeFor(80), 'B');
      expect(gradeFor(79), 'C');
      expect(gradeFor(70), 'C');
      expect(gradeFor(69), 'D');
      expect(gradeFor(60), 'D');
      expect(gradeFor(59), 'F');
      expect(gradeFor(0), 'F');
    });
  });

  group('normalization across targets', () {
    final perfect =
        SkillParser().parseFile(fixture('excellent/pdf-form-filler/SKILL.md'));

    test('a flawless skill scores 100 on every target', () {
      for (final target in Target.values) {
        final result = scorer.score(perfect, target);
        expect(result.score, 100, reason: target.name);
        expect(result.grade, 'A');
      }
    });

    test('targets activate different rule subsets', () {
      final registry = RuleRegistry();
      final universal = registry.activeRules(Target.universal);
      final claude = registry.activeRules(Target.claude);
      final codex = registry.activeRules(Target.codex);
      final antigravity = registry.activeRules(Target.antigravity);
      expect(universal.map((r) => r.id), contains('B4_frontloaded_triggers'));
      expect(
          claude.map((r) => r.id), isNot(contains('B4_frontloaded_triggers')));
      expect(claude.map((r) => r.id), isNot(contains('B5_boundary_clause')));
      expect(codex.map((r) => r.id), isNot(contains('B5_boundary_clause')));
      expect(antigravity.map((r) => r.id),
          isNot(contains('B4_frontloaded_triggers')));
      expect(antigravity.map((r) => r.id), contains('G1_safety_section'));
      expect(codex.map((r) => r.id), isNot(contains('G1_safety_section')));
    });

    test('universal positive rules total exactly 107 points', () {
      // Update this value whenever a rule is added or its maxPoints changes.
      final registry = RuleRegistry();
      final total = registry
          .activeRules(Target.universal)
          .where((r) => r.maxPoints > 0)
          .fold<int>(0, (sum, r) => sum + r.maxPoints);
      expect(total, 107);
    });
  });

  group('penalty handling', () {
    test('category G penalty is capped at -15', () {
      // Scripts present, undocumented, with commands and no Safety
      // section: raw penalty would be -8 + -7 = -15 (exactly the cap).
      inTempSkill({
        'SKILL.md':
            manifestWith(body: '```bash\nrm -rf build\n```\nNothing else.'),
        'scripts/mystery.py': 'pass',
      }, (root) {
        final doc = SkillParser().parseFile('$root/SKILL.md');
        final result = scorer.score(doc, Target.universal);
        expect(result.penalty, -15);
        expect(result.penalty >= safetyPenaltyCap, isTrue);
      });
    });

    test('no penalty when category G does not apply', () {
      final doc = parseDoc(manifestWith(body: 'Prose only.'));
      final result = scorer.score(doc, Target.universal);
      expect(result.penalty, 0);
    });
  });

  group('determinism and ordering', () {
    test('same input produces identical results', () {
      final doc =
          SkillParser().parseFile(fixture('broken/legacy-notes/SKILL.md'));
      final a = scorer.score(doc, Target.universal);
      final b = scorer.score(doc, Target.universal);
      expect(a.score, b.score);
      expect(a.findings.map((f) => '${f.ruleId}:${f.line}'),
          b.findings.map((f) => '${f.ruleId}:${f.line}'));
    });

    test('findings are sorted by category, rule id, then line', () {
      final doc =
          SkillParser().parseFile(fixture('broken/legacy-notes/SKILL.md'));
      final findings = scorer.score(doc, Target.universal).findings;
      for (var i = 1; i < findings.length; i++) {
        final prev = findings[i - 1];
        final curr = findings[i];
        final byCategory = prev.category.compareTo(curr.category);
        expect(byCategory <= 0, isTrue);
        if (byCategory == 0) {
          final byRule = prev.ruleId.compareTo(curr.ruleId);
          expect(byRule <= 0, isTrue);
          if (byRule == 0) {
            expect((prev.line ?? 0) <= (curr.line ?? 0), isTrue);
          }
        }
      }
    });
  });

  group('end-to-end fixtures', () {
    test('excellent fixture scores an A', () {
      final doc = SkillParser()
          .parseFile(fixture('excellent/pdf-form-filler/SKILL.md'));
      final result = scorer.score(doc, Target.universal);
      expect(result.score, greaterThanOrEqualTo(90));
      expect(result.grade, 'A');
    });

    test('mediocre fixture scores a C', () {
      final doc = SkillParser()
          .parseFile(fixture('mediocre/spreadsheet-skill/SKILL.md'));
      final result = scorer.score(doc, Target.universal);
      expect(result.score, inInclusiveRange(70, 79));
      expect(result.grade, 'C');
    });

    test('broken fixture scores an F', () {
      final doc =
          SkillParser().parseFile(fixture('broken/legacy-notes/SKILL.md'));
      final result = scorer.score(doc, Target.universal);
      expect(result.score, lessThan(60));
      expect(result.grade, 'F');
    });
  });
}
