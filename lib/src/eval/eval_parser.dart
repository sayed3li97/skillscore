// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'eval_document.dart';

/// Result of parsing an `evals.json` file.
class EvalParseResult {
  /// Creates a parse result with an optional document, errors, and warnings.
  const EvalParseResult({
    this.document,
    this.errors = const [],
    this.warnings = const [],
  });

  /// The parsed document, or null if parsing failed.
  final EvalDocument? document;

  /// Hard errors that prevent the document from being used (e.g. missing
  /// required fields, invalid JSON). Non-empty means [document] is unusable.
  final List<String> errors;

  /// Advisory warnings (e.g. small eval suite). The document is still usable.
  final List<String> warnings;

  /// True when [document] is non-null and [errors] is empty.
  bool get isValid => errors.isEmpty && document != null;
}

/// Parses and validates `evals.json` files.
class EvalParser {
  /// Creates a const parser instance.
  const EvalParser();

  /// Parses [content] (raw JSON string) into an [EvalParseResult].
  ///
  /// [sourcePath] is used only in error messages.
  EvalParseResult parse(String content, {String sourcePath = 'evals.json'}) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return EvalParseResult(
            errors: ['$sourcePath: root must be a JSON object']);
      }
      json = decoded;
    } on FormatException catch (e) {
      return EvalParseResult(
          errors: ['$sourcePath: invalid JSON — ${e.message}']);
    }

    EvalDocument doc;
    try {
      doc = EvalDocument.fromJson(json);
    } on FormatException catch (e) {
      return EvalParseResult(errors: ['$sourcePath: ${e.message}']);
    }

    final (errors, warnings) = _validate(doc, sourcePath);
    return EvalParseResult(document: doc, errors: errors, warnings: warnings);
  }

  /// Reads and parses [file].
  EvalParseResult parseFile(File file) {
    if (!file.existsSync()) {
      return EvalParseResult(errors: [
        '${file.path}: evals.json not found. '
            'Run "skillscore eval init <path>" to scaffold one.',
      ]);
    }
    final content = file.readAsStringSync();
    return parse(content, sourcePath: file.path);
  }

  /// Returns `(errors, warnings)` — errors block [isValid], warnings do not.
  (List<String>, List<String>) _validate(EvalDocument doc, String source) {
    final errors = <String>[];
    final warnings = <String>[];

    if (doc.queries.isEmpty) {
      errors.add('$source: "queries" must not be empty');
    }
    if (doc.triggerQueries.isEmpty) {
      errors.add('$source: "queries" must include at least one trigger query '
          '(should_trigger: true)');
    }
    if (doc.nonTriggerQueries.isEmpty) {
      errors.add('$source: "queries" must include at least one non-trigger '
          'query (should_trigger: false)');
    }
    // Advisory: small suites are usable but less reliable.
    if (doc.queries.length < 4 && errors.isEmpty) {
      warnings.add('$source: eval suite has only ${doc.queries.length} quer'
          '${doc.queries.length == 1 ? 'y' : 'ies'}; '
          'the Anthropic guide recommends at least 10 trigger + 10 non-trigger');
    }
    return (errors, warnings);
  }
}
