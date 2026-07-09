// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import '../model/finding.dart';

/// What `--fix` did to one manifest file.
class FileFixResult {
  /// Creates a file-fix result.
  const FileFixResult({
    required this.manifestPath,
    required this.applied,
    this.error,
  });

  /// The manifest that was fixed.
  final String manifestPath;

  /// The fixes that were actually written, in line order.
  final List<FindingFix> applied;

  /// A read/write error message, when the file could not be fixed.
  final String? error;

  /// Whether any fix was written to disk.
  bool get changed => applied.isNotEmpty;
}

/// Applies the safe, mechanical fixes carried by findings back to the
/// manifest on disk.
///
/// The only fix today is a top-level frontmatter key rename. The fixer is
/// deterministic and idempotent: re-running it makes no further change,
/// because a rename only applies when the misspelled key still sits at the
/// start of its recorded line. Line endings and a leading UTF-8 BOM are
/// preserved.
class SkillFixer {
  /// Creates a fixer.
  const SkillFixer();

  /// Applies every [FindingFix] carried by [findings] to the file at
  /// [manifestPath], writing it back only when something changed.
  FileFixResult fix(String manifestPath, List<Finding> findings) {
    final fixes = [
      for (final f in findings)
        if (f.fix != null) f.fix!,
    ]..sort((a, b) => a.line.compareTo(b.line));
    if (fixes.isEmpty) {
      return FileFixResult(manifestPath: manifestPath, applied: const []);
    }

    String raw;
    try {
      raw = File(manifestPath).readAsStringSync();
    } on FileSystemException catch (e) {
      return FileFixResult(
          manifestPath: manifestPath, applied: const [], error: e.message);
    }

    var text = raw;
    final hasBom = text.startsWith('\uFEFF');
    if (hasBom) text = text.substring(1);
    final crlf = text.contains('\r\n');
    final lines = text.split(RegExp(r'\r\n|\r|\n'));

    final leading = RegExp(r'^\s*');
    final applied = <FindingFix>[];
    for (final fix in fixes) {
      final idx = fix.line - 1;
      if (idx < 0 || idx >= lines.length) continue;
      final line = lines[idx];
      final indent = leading.firstMatch(line)!.group(0)!;
      final afterIndent = line.substring(indent.length);
      // Only rename when the misspelled key is still there, followed by a
      // colon. This keeps the fix idempotent and refuses anything unexpected.
      if (!afterIndent.startsWith(fix.fromKey)) continue;
      final rest = afterIndent.substring(fix.fromKey.length);
      if (!rest.replaceFirst(leading, '').startsWith(':')) continue;
      lines[idx] = '$indent${fix.toKey}$rest';
      applied.add(fix);
    }

    if (applied.isEmpty) {
      return FileFixResult(manifestPath: manifestPath, applied: const []);
    }

    final joined = lines.join(crlf ? '\r\n' : '\n');
    try {
      File(manifestPath).writeAsStringSync((hasBom ? '\uFEFF' : '') + joined);
    } on FileSystemException catch (e) {
      return FileFixResult(
          manifestPath: manifestPath, applied: const [], error: e.message);
    }
    return FileFixResult(manifestPath: manifestPath, applied: applied);
  }
}
