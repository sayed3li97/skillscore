// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../model/skill_document.dart';

/// Thrown for usage-level problems: bad paths, unreadable or binary
/// input. The CLI maps this to exit code 2.
class SkillInputException implements Exception {
  /// Creates an input exception with a human-readable [message].
  SkillInputException(this.message);

  /// The reason the input could not be processed.
  final String message;

  @override
  String toString() => message;
}

/// Discovers and parses skill manifests.
///
/// Discovery is name-agnostic and case-insensitive: any `skill.md` /
/// `SKILL.md` / `Skill.md` is a manifest, and a path pointing directly
/// at a Markdown file is scored as a manifest regardless of its name.
class SkillParser {
  /// Side folders recognized next to a manifest.
  static const List<String> sideFolders = [
    'references',
    'examples',
    'scripts',
    'assets',
  ];

  /// Discovers every skill manifest reachable from [rootPath].
  ///
  /// - A file path: that file is the manifest.
  /// - A folder containing a manifest: a single skill.
  /// - Any other folder: walked recursively (without following
  ///   symlinked directories, so links cannot escape the tree); every
  ///   directory holding a manifest contributes one skill.
  ///
  /// Results are sorted by path for deterministic output. Non-fatal
  /// problems (unreadable subfolders) are appended to [warnings].
  List<String> discoverManifests(String rootPath, {List<String>? warnings}) {
    final type = FileSystemEntity.typeSync(rootPath);
    if (type == FileSystemEntityType.notFound) {
      throw SkillInputException('Path does not exist: $rootPath');
    }
    if (type == FileSystemEntityType.file ||
        (type == FileSystemEntityType.link &&
            FileSystemEntity.typeSync(rootPath, followLinks: true) ==
                FileSystemEntityType.file)) {
      _ensureReadableText(rootPath);
      return [p.normalize(rootPath)];
    }
    final dir = Directory(rootPath);
    final direct = _manifestIn(dir);
    if (direct != null) return [p.normalize(direct)];

    final manifests = <String>[];
    _walk(dir, manifests, warnings ?? <String>[]);
    manifests.sort();
    return manifests;
  }

  void _walk(Directory dir, List<String> manifests, List<String> warnings) {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException catch (e) {
      warnings.add('Skipping unreadable directory ${dir.path}: ${e.message}');
      return;
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    final manifest = _manifestIn(dir);
    if (manifest != null) manifests.add(p.normalize(manifest));
    for (final entry in entries) {
      final base = p.basename(entry.path);
      if (base.startsWith('.')) continue;
      if (entry is Directory) {
        // Skip side folders of an already-discovered skill.
        if (manifest != null && sideFolders.contains(base)) continue;
        _walk(entry, manifests, warnings);
      }
    }
  }

  String? _manifestIn(Directory dir) {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      return null;
    }
    final candidates = entries
        .whereType<File>()
        .where((f) => p.basename(f.path).toLowerCase() == 'skill.md')
        .map((f) => f.path)
        .toList()
      ..sort();
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Parses the manifest at [manifestPath] together with its side folders.
  SkillDocument parseFile(String manifestPath) {
    _ensureReadableText(manifestPath);
    final content = File(manifestPath).readAsStringSync();
    return parseContent(content, manifestPath: manifestPath);
  }



  /// Parses raw [content] as a manifest located at [manifestPath].
  ///
  /// Handles a UTF-8 BOM and both `\n` and `\r\n` line endings without
  /// corrupting reported line numbers. Missing or malformed frontmatter
  /// never throws; rules report it as findings instead.
  SkillDocument parseContent(String content, {required String manifestPath}) {
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
        for (var i = 1; i < close; i++) {
          final line = lines[i];
          if (nameLine == null && RegExp(r'^name\s*:').hasMatch(line)) {
            nameLine = i + 1;
          }
          if (descriptionLine == null &&
              RegExp(r'^description\s*:').hasMatch(line)) {
            descriptionLine = i + 1;
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
    final warnings = <String>[];

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
      references: _readSideFolder(skillRoot, 'references', warnings),
      examples: _readSideFolder(skillRoot, 'examples', warnings),
      scripts: _readSideFolder(skillRoot, 'scripts', warnings),
      assets: _readSideFolder(skillRoot, 'assets', warnings),
      parseWarnings: warnings,
    );
  }

  List<SideFile> _readSideFolder(
      String skillRoot, String folder, List<String> warnings) {
    final dir = Directory(p.join(skillRoot, folder));
    if (!dir.existsSync()) return const [];
    final files = <SideFile>[];
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(recursive: true, followLinks: false);
    } on FileSystemException catch (e) {
      warnings.add('Skipping unreadable folder ${dir.path}: ${e.message}');
      return const [];
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries.whereType<File>()) {
      final rel = p.relative(entry.path, from: skillRoot).replaceAll(r'\', '/');
      List<String>? lines;
      try {
        final raw = entry.readAsBytesSync();
        if (!_looksBinary(raw)) {
          var text = String.fromCharCodes(raw);
          try {
            text = entry.readAsStringSync();
          } on FileSystemException {
            // Fall back to the latin-1 style decode above.
          }
          if (text.startsWith('\uFEFF')) text = text.substring(1);
          lines = text.split(RegExp(r'\r\n|\r|\n'));
        }
      } on FileSystemException catch (e) {
        warnings.add('Skipping unreadable file ${entry.path}: ${e.message}');
      }
      files.add(SideFile(
        relativePath: rel,
        absolutePath: entry.path,
        lines: lines,
      ));
    }
    return files;
  }

  void _ensureReadableText(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SkillInputException('File does not exist: $path');
    }
    List<int> head;
    try {
      final raf = file.openSync();
      try {
        head = raf.readSync(8192);
      } finally {
        raf.closeSync();
      }
    } on FileSystemException catch (e) {
      throw SkillInputException('Cannot read $path: ${e.message}');
    }
    if (_looksBinary(head)) {
      throw SkillInputException(
          'Not a text file (binary content detected): $path');
    }
  }

  bool _looksBinary(List<int> bytes) => bytes.contains(0);
}
