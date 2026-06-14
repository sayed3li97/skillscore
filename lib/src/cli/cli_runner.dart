// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:args/args.dart';

import '../model/finding.dart';
import '../parsing/skill_parser.dart';
import '../reporting/json_reporter.dart';
import '../reporting/pretty_reporter.dart';
import '../reporting/sarif_reporter.dart';
import '../rules/registry.dart';
import '../scoring/scorer.dart';
import '../tokens/token_counter.dart';
import '../version.dart';

/// Exit code for success.
const int exitOk = 0;

/// Exit code when a skill fails the threshold or strict mode.
const int exitFailedGate = 1;

/// Exit code for usage errors (bad path, unreadable file, bad flag).
const int exitUsage = 2;

/// Runs the skillscore CLI. Returns the process exit code.
///
/// Output goes to [out] and errors to [err] so tests can run the CLI
/// fully in-process.
Future<int> runCli(List<String> arguments,
    {StringSink? out, StringSink? err}) async {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  final registry = RuleRegistry();

  final parser = ArgParser()
    ..addOption('target',
        help: 'Rule profile to score against.',
        allowed: ['claude', 'antigravity', 'codex', 'universal'],
        defaultsTo: 'universal')
    ..addOption('format',
        help: 'Output format.',
        allowed: ['pretty', 'json', 'sarif'],
        defaultsTo: 'pretty')
    ..addOption('min-score',
        help: 'Exit non-zero if any skill scores below this (CI gating).')
    ..addFlag('strict',
        negatable: false, help: 'Treat warning-level findings as errors.')
    ..addFlag('quiet',
        negatable: false, help: 'Print only the final score line per skill.')
    ..addFlag('no-color', negatable: false, help: 'Disable ANSI colors.')
    ..addFlag('version', negatable: false, help: 'Print the version.')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Print this usage information.');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderrSink.writeln('Error: ${e.message}');
    stderrSink.writeln();
    stderrSink.writeln(_usage(parser));
    return exitUsage;
  }

  if (args['help'] as bool) {
    stdoutSink.writeln(_usage(parser));
    return exitOk;
  }
  if (args['version'] as bool) {
    stdoutSink.writeln('skillscore $packageVersion');
    return exitOk;
  }

  final rest = args.rest;
  if (rest.isEmpty) {
    stderrSink.writeln('Error: no path or command given.');
    stderrSink.writeln();
    stderrSink.writeln(_usage(parser));
    return exitUsage;
  }

  if (rest.first == 'rules') {
    _printRules(stdoutSink, registry);
    return exitOk;
  }
  if (rest.first == 'explain') {
    if (rest.length < 2) {
      stderrSink.writeln('Error: "explain" needs a rule id, '
          'e.g. skillscore explain B2_description_when');
      return exitUsage;
    }
    return _explain(stdoutSink, stderrSink, registry, rest[1]);
  }

  return _score(args, registry, stdoutSink, stderrSink);
}

String _usage(ArgParser parser) => '''
skillscore — lint and score AI agent skills (SKILL.md).

Usage:
  skillscore <path> [<path> ...]  Score one or more manifests, folders, or trees
  skillscore rules                List every rule
  skillscore explain <rule-id>    Explain one rule and its fix
  skillscore --version

Options:
${parser.usage}

Exit codes: 0 ok | 1 below --min-score or --strict findings | 2 usage error''';

void _printRules(StringSink out, RuleRegistry registry) {
  out.writeln('ID                            PTS  SEVERITY  TARGETS'
      '                SOURCE');
  for (final rule in registry.rules) {
    final targets = rule.targets.length == Target.values.length
        ? 'all'
        : (rule.targets.map((t) => t.name).toList()..sort()).join(',');
    out.writeln('${rule.id.padRight(30)}'
        '${rule.maxPoints.toString().padLeft(3)}  '
        '${rule.defaultSeverity.name.padRight(8)}  '
        '${targets.padRight(21)}  '
        '${rule.sourceGuide}');
  }
  out.writeln();
  out.writeln('Run "skillscore explain <id>" for a rule\'s rationale and fix.');
}

int _explain(StringSink out, StringSink err, RuleRegistry registry, String id) {
  final rule = registry.byId(id);
  if (rule == null) {
    err.writeln('Error: unknown rule id "$id". '
        'Run "skillscore rules" to list all rules.');
    return exitUsage;
  }
  out.writeln(rule.id);
  out.writeln('  Title:    ${rule.title}');
  out.writeln('  Category: ${rule.category} — '
      '${categoryNames[rule.category]}');
  out.writeln('  Points:   ${rule.maxPoints}');
  out.writeln('  Severity: ${rule.defaultSeverity.name}');
  out.writeln('  Targets:  '
      '${(rule.targets.map((t) => t.name).toList()..sort()).join(', ')}');
  out.writeln('  Source:   ${rule.sourceGuide} authoring guide');
  out.writeln();
  out.writeln('  Why: ${rule.rationale}');
  out.writeln();
  out.writeln('  Fix: ${rule.fixHint}');
  return exitOk;
}

int _score(
    ArgResults args, RuleRegistry registry, StringSink out, StringSink err) {
  final target = targetFromName(args['target'] as String)!;
  final format = args['format'] as String;
  final strict = args['strict'] as bool;
  final quiet = args['quiet'] as bool;
  final noColor = args['no-color'] as bool;

  int? minScore;
  final minScoreRaw = args['min-score'] as String?;
  if (minScoreRaw != null) {
    minScore = int.tryParse(minScoreRaw);
    if (minScore == null || minScore < 0 || minScore > 100) {
      err.writeln('Error: --min-score must be an integer 0..100 '
          '(got "$minScoreRaw").');
      return exitUsage;
    }
  }

  final paths = args.rest;
  final skillParser = SkillParser();
  final warnings = <String>[];
  final seen = <String>{};
  final manifests = <String>[];

  for (final path in paths) {
    List<String> found;
    try {
      found = skillParser.discoverManifests(path, warnings: warnings);
    } on SkillInputException catch (e) {
      if (paths.length == 1) {
        err.writeln('Error: ${e.message}');
        return exitUsage;
      }
      warnings.add('$path: ${e.message}');
      continue;
    }
    if (found.isEmpty) {
      if (paths.length == 1) {
        err.writeln('Error: no skill manifest (SKILL.md) found under: $path');
        return exitUsage;
      }
      warnings.add('no skill manifest (SKILL.md) found under: $path');
      continue;
    }
    for (final m in found) {
      if (seen.add(m)) manifests.add(m);
    }
  }

  if (manifests.isEmpty) {
    err.writeln(
        'Error: no skill manifests found under any of the given paths.');
    return exitUsage;
  }

  // Sort for deterministic output when paths are combined from multiple inputs.
  manifests.sort();

  final scorer = Scorer(registry, tokenCounter: TokenCounter());
  final results = <ScoreResult>[];
  for (final manifest in manifests) {
    try {
      final doc = skillParser.parseFile(manifest);
      warnings.addAll(doc.parseWarnings);
      results.add(scorer.score(doc, target));
    } on SkillInputException catch (e) {
      if (manifests.length == 1) {
        err.writeln('Error: ${e.message}');
        return exitUsage;
      }
      warnings.add('Skipping $manifest: ${e.message}');
    }
  }
  if (results.isEmpty) {
    err.writeln('Error: no readable skill manifests found.');
    return exitUsage;
  }

  for (final warning in warnings) {
    err.writeln('warning: $warning');
  }

  switch (format) {
    case 'json':
      out.writeln(const JsonReporter().report(results));
    case 'sarif':
      out.writeln(SarifReporter(registry).report(results));
    default:
      out.write(PrettyReporter(color: !noColor, quiet: quiet).report(results));
  }

  var failed = false;
  if (minScore != null) {
    failed = results.any((r) => r.score < minScore!);
  }
  if (strict) {
    failed = failed ||
        results.any((r) =>
            r.hasSeverity(Severity.error) || r.hasSeverity(Severity.warning));
  }
  return failed ? exitFailedGate : exitOk;
}
