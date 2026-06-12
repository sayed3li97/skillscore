// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('E1_anti_patterns', () {
    final rule = AntiPatternsRule();
    test('passes with explicit prohibitions', () {
      for (final body in [
        'Do not edit generated files.',
        "Don't commit secrets.",
        'Never push directly to main.',
        'Avoid global state.',
      ]) {
        expect(evaluate(rule, manifestWith(body: body)).points, 6,
            reason: body);
      }
    });
    test('fails a happy-path-only body', () {
      final result =
          evaluate(rule, manifestWith(body: 'Always write good code.'));
      expect(result.points, 0);
    });
  });

  group('E2_workflow_checklist', () {
    final rule = WorkflowChecklistRule();
    test('passes a numbered workflow', () {
      final result =
          evaluate(rule, manifestWith(body: '1. First step.\n2. Second step.'));
      expect(result.points, 5);
    });
    test('passes a markdown task list', () {
      final result =
          evaluate(rule, manifestWith(body: '- [ ] Step one\n- [x] Done'));
      expect(result.points, 5);
    });
    test('fails prose-only workflows', () {
      final result = evaluate(rule,
          manifestWith(body: 'First do the thing, then the other thing.'));
      expect(result.points, 0);
    });
    test('a single numbered line is not a workflow', () {
      final result =
          evaluate(rule, manifestWith(body: '1. Only one step.\nprose'));
      expect(result.points, 0);
    });
  });

  group('E3_feedback_loop', () {
    final rule = FeedbackLoopRule();
    test('passes when the body validates and iterates', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: 'Run the tests; if any fail, fix the code and re-run '
                  'until they pass.'));
      expect(result.points, 5);
    });
    test('fails validation without iteration', () {
      final result =
          evaluate(rule, manifestWith(body: 'Run the tests at the end.'));
      expect(result.points, 0);
    });
    test('fails iteration without validation', () {
      final result =
          evaluate(rule, manifestWith(body: 'Repeat the steps until done.'));
      expect(result.points, 0);
    });
  });

  group('E4_code_example', () {
    final rule = CodeExampleRule();
    test('passes with a non-empty fenced block', () {
      final result =
          evaluate(rule, manifestWith(body: '```bash\necho hello\n```'));
      expect(result.points, 4);
    });
    test('fails without any fenced block', () {
      expect(evaluate(rule, manifestWith(body: 'No examples here.')).points, 0);
    });
    test('an empty fence does not count', () {
      expect(evaluate(rule, manifestWith(body: '```\n```')).points, 0);
    });
  });
}
