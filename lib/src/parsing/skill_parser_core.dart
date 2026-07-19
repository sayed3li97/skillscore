// SPDX-License-Identifier: Apache-2.0

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../model/skill_document.dart';

/// Parses raw manifest [content] into a [SkillDocument] without any
/// `dart:io` dependency, so it compiles to JS/Wasm for the web playground.
///
/// Side files (`references/`, `examples/`, `scripts/`, `assets/`) are supplied
/// by the caller because reading them needs a filesystem: the native
/// [SkillParser] reads them from disk and passes them here, while the web build
/// passes none. Everything else — frontmatter, body, line index — is pure text
/// processing.
///
/// Handles a UTF-8 BOM and both `\n` and `\r\n` line endings without corrupting
/// reported line numbers. Missing or malformed frontmatter never throws; rules
/// report it as findings instead.
SkillDocument parseSkillContent(
  String content, {
  required String manifestPath,
  List<SideFile> references = const [],
  List<SideFile> examples = const [],
  List<SideFile> scripts = const [],
  List<SideFile> assets = const [],
  List<String> parseWarnings = const [],
}) {
  var text = content;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final lines = text.split(RegExp(r'\r\n|\r|\n'));

  var hasDelimiters = false;
  var valid = false;
  String? error;
  var frontmatter = <String, Object?>{};
  var bodyStartLine = 1;
  int? nameLine;
  int? descriptionLine;
  final keyLines = <String, int>{};

  if (lines.isNotEmpty && lines.first.trim() == '---') {
    var close = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        close = i;
        break;
      }
    }
    if (close > 0) {
      hasDelimiters = true;
      final yamlText = lines.sublist(1, close).join('\n');
      try {
        final parsed = loadYaml(yamlText);
        if (parsed is YamlMap) {
          frontmatter = <String, Object?>{
            for (final entry in parsed.entries)
              entry.key.toString(): entry.value,
          };
          valid = true;
        } else if (parsed == null) {
          error = 'Frontmatter block is empty.';
        } else {
          error = 'Frontmatter is not a YAML map.';
        }
      } on YamlException catch (e) {
        error = 'Malformed YAML frontmatter: ${e.message}';
      }
      bodyStartLine = close + 2;
      final keyPattern = RegExp(r'^([A-Za-z0-9_-]+)\s*:');
      for (var i = 1; i < close; i++) {
        final line = lines[i];
        if (nameLine == null && RegExp(r'^name\s*:').hasMatch(line)) {
          nameLine = i + 1;
        }
        if (descriptionLine == null &&
            RegExp(r'^description\s*:').hasMatch(line)) {
          descriptionLine = i + 1;
        }
        // Record the first line of each top-level key (column 0, so
        // nested/indented keys under maps like `metadata:` are ignored).
        final match = keyPattern.firstMatch(line);
        if (match != null) {
          keyLines.putIfAbsent(match.group(1)!, () => i + 1);
        }
      }
    } else {
      error = 'Frontmatter opening "---" has no closing "---".';
      bodyStartLine = 1;
    }
  }

  final bodyLines = hasDelimiters
      ? lines.sublist((bodyStartLine - 1).clamp(0, lines.length))
      : lines;
  final body = bodyLines.join('\n');

  final skillRoot = p.dirname(p.normalize(manifestPath));

  return SkillDocument(
    manifestPath: p.normalize(manifestPath),
    skillRoot: skillRoot,
    rawContent: text,
    frontmatter: frontmatter,
    hasFrontmatterDelimiters: hasDelimiters,
    frontmatterValid: valid,
    frontmatterError: error,
    body: body,
    bodyLines: bodyLines,
    bodyStartLine: hasDelimiters ? bodyStartLine : 1,
    nameLine: nameLine,
    descriptionLine: descriptionLine,
    frontmatterKeyLines: keyLines,
    references: references,
    examples: examples,
    scripts: scripts,
    assets: assets,
    parseWarnings: parseWarnings,
  );
}
