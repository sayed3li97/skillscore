// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import '../model/skill_document.dart';
import 'eval_api_client.dart';
import 'eval_document.dart';
import 'eval_query.dart';
import 'eval_result.dart';

/// Callback invoked after each API call to report live progress.
typedef ProgressCallback = void Function(String message);

/// Resolves the Anthropic API key from the environment or config file.
///
/// Lookup order:
/// 1. `ANTHROPIC_API_KEY` environment variable.
/// 2. `~/.config/anthropic/api_key` file.
String? resolveApiKey() {
  final env = Platform.environment['ANTHROPIC_API_KEY'];
  if (env != null && env.trim().isNotEmpty) return env.trim();

  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null) {
    final f = File('$home/.config/anthropic/api_key');
    if (f.existsSync()) {
      final content = f.readAsStringSync().trim();
      if (content.isNotEmpty) return content;
    }
  }
  return null;
}

/// Runs the eval protocol and returns an [EvalRunResult].
///
/// Each query in [document] is invoked [EvalDocument.runsPerQuery] times via
/// [client]. Queries run concurrently up to [maxConcurrency] simultaneous API
/// calls. Progress is reported via [onProgress].
class EvalRunner {
  /// Creates a runner with optional API client, concurrency, and progress hook.
  const EvalRunner({
    EvalApiClient? client,
    this.maxConcurrency = 5,
    this.onProgress,
  }) : _client = client ?? const AnthropicEvalClient();

  final EvalApiClient _client;

  /// Maximum number of simultaneous API calls.
  final int maxConcurrency;

  /// Optional callback for live progress. Receives a line per invocation.
  final ProgressCallback? onProgress;

  /// Runs the full eval protocol and returns an [EvalRunResult].
  Future<EvalRunResult> run(
    EvalDocument document,
    SkillDocument skill,
    String apiKey,
  ) async {
    final description = skill.description ?? '';
    final skillName = document.skillName;
    final queries = document.queries;

    // Build the flat list of (queryIndex, runIndex) invocations.
    final invocations = [
      for (var qi = 0; qi < queries.length; qi++)
        for (var ri = 0; ri < document.runsPerQuery; ri++) (qi, ri),
    ];

    // Run with bounded concurrency.
    final semaphore = _Semaphore(maxConcurrency);
    // Store results as list-of-lists: [queryIndex][runIndex] = bool|null.
    final triggered = List.generate(
        queries.length, (_) => List<bool?>.filled(document.runsPerQuery, null));
    final errors = List.generate(queries.length, (_) => <String>[]);

    await Future.wait(invocations.map((inv) async {
      final (qi, ri) = inv;
      await semaphore.acquire();
      try {
        final result = await _client.checkTrigger(
          apiKey: apiKey,
          model: document.model,
          skillName: skillName,
          skillDescription: description,
          query: queries[qi].query,
        );
        triggered[qi][ri] = result.triggered;
        if (result.hasError) {
          errors[qi].add('run ${ri + 1}: ${result.error}');
        }
        _reportProgress(queries[qi], ri + 1, document.runsPerQuery,
            result.triggered, result.error);
      } finally {
        semaphore.release();
      }
    }));

    final queryResults = <QueryResult>[];
    for (var qi = 0; qi < queries.length; qi++) {
      final runs = triggered[qi];
      final completed = runs.where((v) => v != null).length;
      final count = runs.where((v) => v == true).length;
      queryResults.add(QueryResult(
        query: queries[qi],
        triggerCount: count,
        totalRuns: completed,
        errors: errors[qi],
      ));
    }

    return EvalRunResult(
      document: document,
      skillPath: skill.manifestPath,
      queryResults: queryResults,
    );
  }

  void _reportProgress(
      EvalQuery query, int run, int total, bool triggered, String? error) {
    if (onProgress == null) return;
    final label = query.shouldTrigger ? 'T' : 'N';
    final mark = error != null ? '!' : (triggered ? '✓' : '✗');
    final shortQuery = query.query.length > 50
        ? '${query.query.substring(0, 47)}...'
        : query.query;
    onProgress!('  [$label] $mark run $run/$total  "$shortQuery"');
  }
}

/// Simple counting semaphore for bounding concurrent async work.
class _Semaphore {
  _Semaphore(this._max);

  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    if (_count < _max) {
      _count++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
  }

  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _count--;
    }
  }
}
