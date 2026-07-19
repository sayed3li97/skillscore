// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

// Deterministic stand-in for the BPE counter: one token per character. Lets the
// tests assert exact totals without depending on tiktoken's vocabulary.
int _chars(String s) => s.length;

SkillEntry _e(String name, String description) =>
    SkillEntry(name: name, path: '$name/SKILL.md', description: description);

void main() {
  group('ListingBudgetAnalyzer', () {
    test('sums name + description tokens per skill, largest first', () {
      final budget = const ListingBudgetAnalyzer(_chars).analyze([
        _e('a', 'x'), // "a\nx"        -> 3
        _e('bbb', 'yyyy'), // "bbb\nyyyy" -> 8
      ]);
      expect(budget.skillCount, 2);
      expect(budget.entries.first.name, 'bbb'); // largest cost first
      expect(budget.entries.first.tokensCl100k, 8);
      expect(budget.entries.last.tokensCl100k, 3);
      expect(budget.totalCl100k, 11);
    });

    test('derives the Claude estimate as a 10% overhead, rounded up', () {
      final budget = const ListingBudgetAnalyzer(_chars).analyze([
        _e('name', 'desc'), // "name\ndesc" -> 9
      ]);
      expect(budget.entries.single.tokensCl100k, 9);
      expect(budget.entries.single.tokensClaude, (9 * 1.10).ceil()); // 10
      expect(budget.totalClaude, (9 * 1.10).ceil());
    });

    test('an empty description still counts the name', () {
      final budget =
          const ListingBudgetAnalyzer(_chars).analyze([_e('solo', '')]);
      expect(budget.entries.single.tokensCl100k, 'solo'.length);
      expect(budget.entries.single.descriptionChars, 0);
      expect(budget.entries.single.overflowsRoutingWindow, isFalse);
    });

    test('flags descriptions past the 250-char routing window', () {
      final long = 'x' * 260;
      final budget = const ListingBudgetAnalyzer(_chars).analyze([
        _e('short', 'ok'),
        _e('long', long),
      ]);
      expect(budget.overflowing.map((e) => e.name), ['long']);
      final over = budget.entries.firstWhere((e) => e.name == 'long');
      expect(over.overflowsRoutingWindow, isTrue);
      expect(over.overflowChars, 260 - routingDescriptionLimit);
      final within = budget.entries.firstWhere((e) => e.name == 'short');
      expect(within.overflowsRoutingWindow, isFalse);
      expect(within.overflowChars, 0);
    });

    test('a description exactly at the limit does not overflow', () {
      final budget = const ListingBudgetAnalyzer(_chars)
          .analyze([_e('edge', 'x' * routingDescriptionLimit)]);
      expect(budget.entries.single.overflowsRoutingWindow, isFalse);
      expect(budget.entries.single.overflowChars, 0);
    });

    test('breaks token ties by name for deterministic ordering', () {
      // Constant counter makes every entry cost the same, isolating the tie
      // break.
      final budget = const ListingBudgetAnalyzer(_constFive).analyze([
        _e('beta', 'x'),
        _e('alpha', 'x'),
      ]);
      expect(budget.entries.map((e) => e.name), ['alpha', 'beta']);
    });

    test('an empty set has zero totals', () {
      final budget = const ListingBudgetAnalyzer(_chars).analyze([]);
      expect(budget.skillCount, 0);
      expect(budget.totalCl100k, 0);
      expect(budget.totalClaude, 0);
      expect(budget.overflowing, isEmpty);
    });
  });
}

int _constFive(String _) => 5;
