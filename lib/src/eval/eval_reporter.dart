// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'eval_result.dart';

// ANSI codes (no-op strings when color is disabled).
String _g(bool c) => c ? '\x1B[32m' : ''; // green
String _r(bool c) => c ? '\x1B[31m' : ''; // red
String _y(bool c) => c ? '\x1B[33m' : ''; // yellow
String _d(bool c) => c ? '\x1B[2m' : ''; // dim
String _b(bool c) => c ? '\x1B[1m' : ''; // bold
String _e(bool c) => c ? '\x1B[0m' : ''; // reset

/// Formats [EvalRunResult] as human-readable text or JSON.
class EvalReporter {
  /// Creates a reporter; set [color] false to disable ANSI codes.
  const EvalReporter({this.color = true});

  /// Whether to emit ANSI color codes in the pretty report.
  final bool color;

  /// Returns a full pretty-printed report.
  String report(EvalRunResult result) {
    final buf = StringBuffer();
    final doc = result.document;

    // Header.
    buf.write('${_b(color)}eval${_e(color)}  ');
    buf.writeln('${_b(color)}${doc.skillName}${_e(color)}  '
        '(${result.skillPath})');
    buf.writeln('${_d(color)}  runs/query    ${doc.runsPerQuery}${_e(color)}');
    buf.writeln(
        '${_d(color)}  threshold     ${doc.triggerThreshold}${_e(color)}');
    buf.writeln('${_d(color)}  queries       '
        '${doc.triggerQueries.length} trigger + '
        '${doc.nonTriggerQueries.length} non-trigger${_e(color)}');
    buf.writeln();

    // Per-query results.
    for (final qr in result.queryResults) {
      final passes = qr.passes(doc.triggerThreshold);
      final color_ = passes ? _g(color) : _r(color);
      final mark = passes ? 'PASS' : 'FAIL';
      final type = qr.query.shouldTrigger ? 'trigger    ' : 'non-trigger';
      final rate = '${qr.triggerCount}/${qr.totalRuns} triggered';
      final shortQ = qr.query.query.length > 55
          ? '${qr.query.query.substring(0, 52)}...'
          : qr.query.query;

      buf.write('  $color_$mark${_e(color)}');
      buf.write('  $type');
      buf.write('  ${rate.padRight(15)}');
      buf.writeln('  "$shortQ"');

      for (final err in qr.errors) {
        buf.writeln('    ${_y(color)}! $err${_e(color)}');
      }
    }

    buf.writeln();

    // Summary.
    final all = result.allPassed;
    final summaryColor = all ? _g(color) : _r(color);
    buf.write('  $summaryColor${_b(color)}');
    buf.write('${result.passCount} passed  ${result.failCount} failed');
    buf.writeln(_e(color));

    if (!all) {
      buf.writeln();
      buf.writeln('  Failures:');
      for (final f in result.failures) {
        final q = f.query;
        final expected = q.shouldTrigger
            ? '>= ${doc.triggerThreshold}'
            : '< ${doc.triggerThreshold}';
        buf.writeln('  ${_r(color)}'
            '  ${q.id ?? ""}  "${q.query}"${_e(color)}');
        buf.writeln('    trigger rate ${f.triggerRate.toStringAsFixed(2)} '
            '(expected $expected)');
      }
    }

    return buf.toString();
  }

  /// Returns the result as a machine-readable JSON string.
  String reportJson(EvalRunResult result) {
    final doc = result.document;
    const enc = JsonEncoder.withIndent('  ');
    return enc.convert({
      'tool': {'name': 'skillscore', 'subcommand': 'eval'},
      'skill': doc.skillName,
      'skillPath': result.skillPath,
      'runsPerQuery': doc.runsPerQuery,
      'triggerThreshold': doc.triggerThreshold,
      'passed': result.allPassed,
      'passCount': result.passCount,
      'failCount': result.failCount,
      'queries': result.queryResults.map((qr) {
        return {
          if (qr.query.id != null) 'id': qr.query.id,
          'query': qr.query.query,
          'shouldTrigger': qr.query.shouldTrigger,
          'triggerCount': qr.triggerCount,
          'totalRuns': qr.totalRuns,
          'triggerRate': double.parse(qr.triggerRate.toStringAsFixed(4)),
          'passed': qr.passes(doc.triggerThreshold),
          if (qr.errors.isNotEmpty) 'errors': qr.errors,
        };
      }).toList(),
    });
  }
}
