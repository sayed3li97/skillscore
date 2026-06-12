// SPDX-License-Identifier: Apache-2.0

import 'package:skillscore/skillscore.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('C1_body_length', () {
    final rule = BodyLengthRule();
    test('passes at 500 lines or fewer', () {
      final body = List.filled(500, 'line').join('\n');
      expect(evaluate(rule, manifestWith(body: body)).points, 6);
    });
    test('degrades linearly between 500 and 1000 lines', () {
      final body = List.filled(750, 'line').join('\n');
      final result = evaluate(rule, manifestWith(body: body));
      expect(result.points, 3);
      expect(result.findings, hasLength(1));
    });
    test('awards zero at 1000+ lines', () {
      final body = List.filled(1100, 'line').join('\n');
      expect(evaluate(rule, manifestWith(body: body)).points, 0);
    });
  });

  group('C2_explainer_bloat', () {
    final rule = ExplainerBloatRule();
    test('passes a body with no definitions of common knowledge', () {
      expect(
          evaluate(rule, manifestWith(body: 'Run the converter on input.'))
              .points,
          5);
    });
    test('flags definitional sentences', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: 'Dart is a popular programming language.\n'
                  'Use it to build the tool.'));
      expect(result.points, 2.5);
      expect(result.findings.single.line, isNotNull);
    });
    test('two bloat lines reduce the score to zero', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: 'Dart is a popular programming language.\n'
                  'HTTP stands for HyperText Transfer Protocol.'));
      expect(result.points, 0);
      expect(result.findings, hasLength(2));
    });
    test('ignores definitions inside code fences', () {
      final result = evaluate(
          rule,
          manifestWith(
              body: '```\nDart is a popular programming language.\n```'));
      expect(result.points, 5);
    });
  });

  group('C3_excessive_optionality', () {
    final rule = ExcessiveOptionalityRule();
    test('passes normal prose', () {
      expect(
          evaluate(rule, manifestWith(body: 'Use a comma or a semicolon.'))
              .points,
          4);
    });
    test('flags long "or" chains', () {
      final result = evaluate(rule,
          manifestWith(body: 'You can use X, or Y, or Z, or anything else.'));
      expect(result.points, 2);
      expect(result.findings, hasLength(1));
    });
  });
}
