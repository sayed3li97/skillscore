// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../analysis/conflicts.dart';
import '../baseline/baseline.dart';
import '../eval/eval_parser.dart';
import '../eval/eval_reporter.dart';
import '../eval/eval_runner.dart';
import '../eval/eval_scaffolder.dart';
import '../fixing/fixer.dart';
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
    ..addOption('baseline',
        help: 'Gate on NEW findings only, tolerating those recorded in this '
            'baseline file. The file is created from the current findings if '
            'it does not exist.')
    ..addFlag('update-baseline',
        negatable: false,
        help: 'Rewrite the --baseline file from the current findings.')
    ..addOption('max-overlap',
        help: '(conflicts) Flag skill pairs whose trigger overlap is at least '
            'this (0.0 to 1.0); exit non-zero when any pair meets it.')
    ..addFlag('strict',
        negatable: false, help: 'Treat warning-level findings as errors.')
    ..addFlag('fix',
        negatable: false,
        help: 'Apply safe auto-fixes in place '
            '(e.g. rename a misspelled frontmatter key), then re-score.')
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
  if (rest.first == 'eval') {
    return _evalCommand(rest.sublist(1), args, stdoutSink, stderrSink);
  }
  if (rest.first == 'conflicts') {
    return _conflicts(rest.sublist(1), args, stdoutSink, stderrSink);
  }

  return _score(args, registry, stdoutSink, stderrSink);
}

String _usage(ArgParser parser) => '''
skillscore — lint and score AI agent skills (SKILL.md).

Usage:
  skillscore <path> [<path> ...]       Score one or more manifests, folders, or trees
  skillscore rules                     List every rule
  skillscore explain <rule-id>         Explain one rule and its fix
  skillscore eval init <path>          Scaffold evals.json next to SKILL.md
  skillscore eval validate <path>      Validate an existing evals.json
  skillscore eval run <path>           Run trigger-rate evals (offline, no API key)
  skillscore conflicts <path> ...      Find skills whose descriptions trigger on the same requests
  skillscore --version

Options:
${parser.usage}

Exit codes: 0 ok | 1 below --min-score, --strict findings, or eval failures | 2 usage error''';

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
  final applyFix = args['fix'] as bool;
  final baselinePath = args['baseline'] as String?;
  final updateBaseline = args['update-baseline'] as bool;
  final quiet = args['quiet'] as bool;
  final noColor = args['no-color'] as bool;

  if (updateBaseline && baselinePath == null) {
    err.writeln('Error: --update-baseline requires --baseline <file>.');
    return exitUsage;
  }

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

  // --fix: apply safe, mechanical fixes in place, then re-score the fixed
  // manifests so the report and the exit code reflect the corrected state.
  final fixSummary = <String>[];
  if (applyFix) {
    const fixer = SkillFixer();
    for (final result in results) {
      final outcome = fixer.fix(result.doc.manifestPath, result.findings);
      if (outcome.error != null) {
        warnings.add('could not fix ${result.doc.manifestPath}: '
            '${outcome.error}');
        continue;
      }
      for (final f in outcome.applied) {
        fixSummary.add('  ${result.doc.displayName}  ${f.summary}  '
            '(line ${f.line})');
      }
    }
    if (fixSummary.isNotEmpty) {
      final rescored = <ScoreResult>[];
      for (final result in results) {
        try {
          rescored.add(scorer.score(
              skillParser.parseFile(result.doc.manifestPath), target));
        } on SkillInputException {
          rescored.add(result);
        }
      }
      results
        ..clear()
        ..addAll(rescored);
    }
  }

  for (final warning in warnings) {
    err.writeln('warning: $warning');
  }

  // --baseline: record the current findings on first use, or gate on only the
  // findings that are new relative to the recorded baseline.
  final baselineLines = <String>[];
  var newFindings = <Finding>[];
  if (baselinePath != null) {
    final entries = <String, List<Finding>>{
      for (final r in results) p.relative(r.doc.manifestPath): r.findings,
    };
    final file = File(baselinePath);
    if (!file.existsSync() || updateBaseline) {
      final baseline = Baseline.record(entries);
      file.writeAsStringSync('${baseline.toJson()}\n');
      baselineLines.add('${updateBaseline ? 'Updated' : 'Wrote'} baseline '
          '$baselinePath: ${baseline.total} '
          '${baseline.total == 1 ? 'finding' : 'findings'} accepted. '
          'New findings will fail future runs.');
    } else {
      Baseline baseline;
      try {
        baseline = Baseline.parse(file.readAsStringSync());
      } on FormatException catch (e) {
        err.writeln('Error: $baselinePath: ${e.message}');
        return exitUsage;
      }
      newFindings = baseline.newFindings(entries);
      if (newFindings.isEmpty) {
        baselineLines
            .add('Baseline: ${baseline.total} accepted, 0 new. Gate clear.');
      } else {
        baselineLines.add('Baseline: ${baseline.total} accepted, '
            '${newFindings.length} '
            '${newFindings.length == 1 ? 'finding is' : 'findings are'} '
            'new (fails the gate):');
        for (final f in newFindings) {
          final loc = f.line == null ? '' : 'line ${f.line}  ';
          baselineLines.add('  ${f.ruleId}  $loc${f.message}');
        }
      }
    }
  }

  if (fixSummary.isNotEmpty && format != 'json' && format != 'sarif') {
    out.writeln('Fixed ${fixSummary.length} '
        '${fixSummary.length == 1 ? 'issue' : 'issues'}:');
    for (final line in fixSummary) {
      out.writeln(line);
    }
    out.writeln();
  }

  switch (format) {
    case 'json':
      out.writeln(const JsonReporter().report(results));
    case 'sarif':
      out.writeln(SarifReporter(registry).report(results));
    default:
      out.write(PrettyReporter(color: !noColor, quiet: quiet).report(results));
  }

  if (baselineLines.isNotEmpty && format != 'json' && format != 'sarif') {
    for (final line in baselineLines) {
      out.writeln(line);
    }
    out.writeln();
  }

  var failed = false;
  if (minScore != null) {
    failed = results.any((r) => r.score < minScore!);
  }
  if (baselinePath != null) {
    // The baseline is the findings gate: fail only on findings that are new
    // since it was recorded (none right after writing it). This is what lets a
    // strict, no-regressions gate be switched on over an existing backlog, so
    // it supersedes --strict here rather than stacking with it.
    failed = failed || newFindings.isNotEmpty;
  } else if (strict) {
    failed = failed ||
        results.any((r) =>
            r.hasSeverity(Severity.error) || r.hasSeverity(Severity.warning));
  }
  return failed ? exitFailedGate : exitOk;
}

// ---------------------------------------------------------------------------
// conflicts subcommand
// ---------------------------------------------------------------------------

int _conflicts(
    List<String> paths, ArgResults args, StringSink out, StringSink err) {
  final format = args['format'] as String;
  final noColor = args['no-color'] as bool;

  double? maxOverlap;
  final rawMax = args['max-overlap'] as String?;
  if (rawMax != null) {
    maxOverlap = double.tryParse(rawMax);
    if (maxOverlap == null || maxOverlap < 0 || maxOverlap > 1) {
      err.writeln(
          'Error: --max-overlap must be a number 0.0 to 1.0 (got "$rawMax").');
      return exitUsage;
    }
  }

  if (paths.isEmpty) {
    err.writeln('Error: "conflicts" needs one or more paths, '
        'e.g. skillscore conflicts skills/');
    return exitUsage;
  }

  final skillParser = SkillParser();
  final warnings = <String>[];
  final seen = <String>{};
  final manifests = <String>[];
  for (final path in paths) {
    try {
      for (final m in skillParser.discoverManifests(path, warnings: warnings)) {
        if (seen.add(m)) manifests.add(m);
      }
    } on SkillInputException catch (e) {
      warnings.add('$path: ${e.message}');
    }
  }
  manifests.sort();

  final entries = <SkillEntry>[];
  for (final manifest in manifests) {
    try {
      final doc = skillParser.parseFile(manifest);
      warnings.addAll(doc.parseWarnings);
      entries.add(SkillEntry(
        name: doc.displayName,
        path: doc.manifestPath,
        description: doc.description ?? '',
      ));
    } on SkillInputException catch (e) {
      warnings.add('Skipping $manifest: ${e.message}');
    }
  }

  for (final warning in warnings) {
    err.writeln('warning: $warning');
  }

  final threshold = maxOverlap ?? 0.5;
  final conflicts = ConflictDetector(threshold: threshold).analyze(entries);

  if (format == 'json') {
    out.writeln(_conflictsJson(entries.length, threshold, conflicts));
  } else {
    _printConflicts(out, entries.length, threshold, conflicts, !noColor);
  }

  // Gate only when --max-overlap was explicitly requested.
  if (maxOverlap != null && conflicts.isNotEmpty) return exitFailedGate;
  return exitOk;
}

String _pct(double v) => '${(v * 100).round()}%';

void _printConflicts(StringSink out, int count, double threshold,
    List<SkillConflict> conflicts, bool color) {
  String paint(String s, String code) => color ? '\x1B[${code}m$s\x1B[0m' : s;

  if (count < 2) {
    out.writeln('Need at least two skills to compare; found $count.');
    return;
  }
  if (conflicts.isEmpty) {
    out.writeln(paint(
        'No overlapping skills at or above ${_pct(threshold)} trigger '
            'overlap. $count skills compared.',
        '32'));
    return;
  }
  out.writeln('${conflicts.length} overlapping '
      '${conflicts.length == 1 ? 'pair' : 'pairs'} '
      '(>= ${_pct(threshold)} trigger overlap) across $count skills:');
  out.writeln();
  for (final c in conflicts) {
    out.writeln('  ${paint(c.a.name, '1')}  <->  ${paint(c.b.name, '1')}   '
        '${paint('${_pct(c.overlap)} overlap', '33')}');
    out.writeln('    shared triggers: ${c.shared.join(', ')}');
    if (!c.bothBounded) {
      final target = c.aHasBoundary ? c.b.name : c.a.name;
      out.writeln('    ${paint('fix:', '2')} add a "do not use for ..." '
          'boundary to $target so the agent can tell them apart.');
    }
    out.writeln();
  }
}

String _conflictsJson(
    int count, double threshold, List<SkillConflict> conflicts) {
  return const JsonEncoder.withIndent('  ').convert({
    'tool': {'name': 'skillscore', 'subcommand': 'conflicts'},
    'skillCount': count,
    'threshold': threshold,
    'conflicts': [
      for (final c in conflicts)
        {
          'a': c.a.name,
          'aPath': c.a.path,
          'b': c.b.name,
          'bPath': c.b.path,
          'overlap': double.parse(c.overlap.toStringAsFixed(4)),
          'shared': c.shared,
          'bothBounded': c.bothBounded,
        },
    ],
  });
}

// ---------------------------------------------------------------------------
// eval subcommand
// ---------------------------------------------------------------------------

Future<int> _evalCommand(
  List<String> rest,
  ArgResults globalArgs,
  StringSink out,
  StringSink err,
) async {
  if (rest.isEmpty) {
    err.writeln('Error: "eval" needs a subcommand: init | validate | run');
    err.writeln('       e.g. skillscore eval init my-skill/');
    return exitUsage;
  }
  final sub = rest.first;
  final subArgs = rest.sublist(1);
  switch (sub) {
    case 'init':
      return _evalInit(subArgs, out, err);
    case 'validate':
      return _evalValidate(subArgs, out, err);
    case 'run':
      return _evalRun(subArgs, globalArgs, out, err);
    default:
      err.writeln('Error: unknown eval subcommand "$sub". '
          'Valid subcommands: init | validate | run');
      return exitUsage;
  }
}

int _evalInit(List<String> args, StringSink out, StringSink err) {
  if (args.isEmpty) {
    err.writeln('Error: "eval init" needs a skill path, '
        'e.g. skillscore eval init my-skill/');
    return exitUsage;
  }
  final skillParser = SkillParser();
  final warnings = <String>[];
  List<String> manifests;
  try {
    manifests = skillParser.discoverManifests(args.first, warnings: warnings);
  } on SkillInputException catch (e) {
    err.writeln('Error: ${e.message}');
    return exitUsage;
  }
  if (manifests.isEmpty) {
    err.writeln(
        'Error: no skill manifest (SKILL.md) found under: ${args.first}');
    return exitUsage;
  }
  if (manifests.length > 1) {
    err.writeln('Error: "eval init" expects a single skill directory; '
        '${manifests.length} manifests found under ${args.first}');
    return exitUsage;
  }
  for (final w in warnings) {
    err.writeln('warning: $w');
  }
  final skill = skillParser.parseFile(manifests.first);
  final evalsPath = p.join(skill.skillRoot, 'evals.json');
  if (File(evalsPath).existsSync()) {
    err.writeln('Error: $evalsPath already exists. '
        'Delete it or edit it manually.');
    return exitUsage;
  }
  final json = const EvalScaffolder().generate(skill);
  File(evalsPath).writeAsStringSync('$json\n');
  out.writeln('Created $evalsPath');
  out.writeln(
      '  ${const EvalScaffolder().scaffold(skill).queries.length} queries scaffolded '
      '(edit before running to add project-specific queries)');
  out.writeln('  Run: skillscore eval validate ${args.first}');
  out.writeln('  Run: skillscore eval run ${args.first}');
  return exitOk;
}

int _evalValidate(List<String> args, StringSink out, StringSink err) {
  if (args.isEmpty) {
    err.writeln('Error: "eval validate" needs a skill path, '
        'e.g. skillscore eval validate my-skill/');
    return exitUsage;
  }
  final skillParser = SkillParser();
  List<String> manifests;
  try {
    manifests = skillParser.discoverManifests(args.first);
  } on SkillInputException catch (e) {
    err.writeln('Error: ${e.message}');
    return exitUsage;
  }
  if (manifests.isEmpty) {
    err.writeln(
        'Error: no skill manifest (SKILL.md) found under: ${args.first}');
    return exitUsage;
  }
  final skill = skillParser.parseFile(manifests.first);
  final evalsPath = p.join(skill.skillRoot, 'evals.json');
  final result = const EvalParser().parseFile(File(evalsPath));
  if (!result.isValid) {
    for (final e in result.errors) {
      err.writeln('error: $e');
    }
    return exitUsage;
  }
  for (final w in result.warnings) {
    err.writeln('warning: $w');
  }
  final doc = result.document!;
  out.writeln('$evalsPath  OK');
  out.writeln('  skill         ${doc.skillName}');
  out.writeln('  queries       '
      '${doc.triggerQueries.length} trigger + '
      '${doc.nonTriggerQueries.length} non-trigger');
  out.writeln('  runs/query    ${doc.runsPerQuery}');
  out.writeln('  threshold     ${doc.triggerThreshold}');
  out.writeln('  total checks  ${doc.queries.length * doc.runsPerQuery}');
  return exitOk;
}

Future<int> _evalRun(
  List<String> args,
  ArgResults globalArgs,
  StringSink out,
  StringSink err,
) async {
  if (args.isEmpty) {
    err.writeln('Error: "eval run" needs a skill path, '
        'e.g. skillscore eval run my-skill/');
    return exitUsage;
  }
  final noColor = globalArgs['no-color'] as bool;
  final format = globalArgs['format'] as String;
  final skillPath = args.first;

  // Discover and parse the skill.
  final skillParser = SkillParser();
  List<String> manifests;
  try {
    manifests = skillParser.discoverManifests(skillPath);
  } on SkillInputException catch (e) {
    err.writeln('Error: ${e.message}');
    return exitUsage;
  }
  if (manifests.isEmpty) {
    err.writeln('Error: no skill manifest (SKILL.md) found under: $skillPath');
    return exitUsage;
  }
  final skill = skillParser.parseFile(manifests.first);

  // Parse evals.json.
  final evalsPath = p.join(skill.skillRoot, 'evals.json');
  final parseResult = const EvalParser().parseFile(File(evalsPath));
  if (!parseResult.isValid) {
    for (final e in parseResult.errors) {
      err.writeln('error: $e');
    }
    return exitUsage;
  }
  for (final w in parseResult.warnings) {
    err.writeln('warning: $w');
  }
  final document = parseResult.document!;

  void progress(String msg) {
    if (format != 'json') out.writeln(msg);
  }

  if (format != 'json') {
    out.writeln('Running '
        '${document.queries.length * document.runsPerQuery} checks '
        '(${document.queries.length} queries × '
        '${document.runsPerQuery} runs)…');
    out.writeln();
  }

  final runner = EvalRunner(onProgress: progress);
  final runResult = await runner.run(document, skill);

  if (format != 'json') out.writeln();

  switch (format) {
    case 'json':
      out.writeln(EvalReporter(color: false).reportJson(runResult));
    default:
      out.write(EvalReporter(color: !noColor).report(runResult));
  }

  return runResult.allPassed ? exitOk : exitFailedGate;
}
