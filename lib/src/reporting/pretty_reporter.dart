// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../scoring/scorer.dart';

/// Renders score results as colored, human-readable text.
class PrettyReporter {
  /// Creates a pretty reporter. Set [color] to false for plain output.
  PrettyReporter({this.color = true, this.quiet = false});

  /// Whether to emit ANSI colors.
  final bool color;

  /// When true, print only the final score line per skill.
  final bool quiet;

  String _paint(String text, String code) =>
      color ? '\x1B[${code}m$text\x1B[0m' : text;

  String _gradeColor(String grade) => switch (grade) {
        'A' => '32', // green
        'B' => '36', // cyan
        'C' => '33', // yellow
        'D' => '35', // magenta
        _ => '31', // red
      };

  String _severityLabel(Severity severity) => switch (severity) {
        Severity.error => _paint('ERROR  ', '31;1'),
        Severity.warning => _paint('WARNING', '33'),
        Severity.info => _paint('INFO   ', '36'),
      };

  /// Renders [results] (already in deterministic order) to a string.
  String report(List<ScoreResult> results) {
    final buffer = StringBuffer();
    for (final result in results) {
      _reportSkill(buffer, result);
    }
    if (!quiet && results.length > 1) {
      final average =
          results.fold<int>(0, (sum, r) => sum + r.score) / results.length;
      final lowest = results.reduce((a, b) => a.score <= b.score ? a : b);
      buffer.writeln(_paint('Summary', '1'));
      buffer.writeln(
          '  ${results.length} skills scored | average ${average.round()} '
          '| lowest ${lowest.score} (${lowest.doc.manifestPath})');
    }
    return buffer.toString();
  }

  void _reportSkill(StringBuffer buffer, ScoreResult result) {
    final scoreLine = 'Score: ${result.score}/100  Grade: ${result.grade}';
    if (quiet) {
      buffer.writeln('${result.doc.displayName}: $scoreLine');
      return;
    }
    buffer.writeln(
        '${_paint(result.doc.displayName, '1')}  (${result.doc.manifestPath})');
    buffer.writeln('  ${_paint(scoreLine, '${_gradeColor(result.grade)};1')}');
    buffer.writeln();
    for (final cat in result.categories) {
      buffer.writeln('  ${cat.category}  ${cat.name.padRight(36)}'
          '${_formatPoints(cat)}  ${_bar(cat)}');
    }
    final bySeverity = <Severity, List<Finding>>{};
    for (final finding in result.findings) {
      bySeverity.putIfAbsent(finding.severity, () => []).add(finding);
    }
    for (final severity in Severity.values) {
      final findings = bySeverity[severity];
      if (findings == null) continue;
      buffer.writeln();
      for (final f in findings) {
        final loc = f.line == null ? '' : '  line ${f.line}';
        buffer.writeln(
            '  ${_severityLabel(severity)} ${_paint(f.ruleId, '1')}$loc');
        buffer.writeln('          ${f.message}');
        buffer.writeln('          ${_paint('fix: ${f.fixHint}', '2')}');
      }
    }
    if (result.findings.isEmpty) {
      buffer.writeln();
      buffer.writeln('  ${_paint('No findings — nice work.', '32')}');
    }
    buffer.writeln();
  }

  String _formatPoints(CategoryScore cat) {
    final awarded = cat.awarded == cat.awarded.roundToDouble()
        ? cat.awarded.round().toString()
        : cat.awarded.toStringAsFixed(1);
    final label = cat.category == 'G' && cat.max == 0
        ? (cat.awarded == 0 ? 'no penalty' : '$awarded penalty')
        : '$awarded/${cat.max}';
    return label.padLeft(10);
  }

  String _bar(CategoryScore cat) {
    if (cat.max == 0) return '';
    const width = 10;
    final filled = (cat.awarded / cat.max * width).clamp(0, width).round();
    final bar = '█' * filled + '░' * (width - filled);
    final code = filled == width ? '32' : (filled >= width ~/ 2 ? '33' : '31');
    return _paint(bar, code);
  }
}
