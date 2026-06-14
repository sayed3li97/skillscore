// SPDX-License-Identifier: Apache-2.0

/// A file discovered alongside a skill manifest (in `references/`,
/// `examples/`, `scripts/`, or `assets/`).
class SideFile {
  /// Creates a side file record.
  const SideFile({
    required this.relativePath,
    required this.absolutePath,
    this.lines,
  });

  /// Path relative to the skill root, always using forward slashes.
  final String relativePath;

  /// Absolute path on disk.
  final String absolutePath;

  /// The file content split into lines, or `null` when the file was
  /// binary or unreadable.
  final List<String>? lines;
}

/// A parsed skill: frontmatter, body, line index, and side files.
///
/// The document is name-agnostic: nothing here assumes any particular
/// skill name, folder name, or manifest file name.
class SkillDocument {
  /// Creates a parsed skill document.
  const SkillDocument({
    required this.manifestPath,
    required this.skillRoot,
    required this.rawContent,
    required this.frontmatter,
    required this.hasFrontmatterDelimiters,
    required this.frontmatterValid,
    required this.body,
    required this.bodyLines,
    required this.bodyStartLine,
    required this.references,
    required this.examples,
    required this.scripts,
    required this.assets,
    this.frontmatterError,
    this.nameLine,
    this.descriptionLine,
    this.parseWarnings = const [],
  });

  /// Path to the manifest file that was parsed.
  final String manifestPath;

  /// The directory containing the manifest.
  final String skillRoot;

  /// The raw manifest text (BOM-stripped, original line endings preserved).
  /// Used for token counting; contains both frontmatter and body.
  final String rawContent;

  /// The parsed YAML frontmatter, or an empty map when missing/invalid.
  final Map<String, Object?> frontmatter;

  /// Whether the file opens with a `---` delimited frontmatter block.
  final bool hasFrontmatterDelimiters;

  /// Whether the frontmatter parsed as a YAML map.
  final bool frontmatterValid;

  /// Parse error text when the frontmatter was malformed.
  final String? frontmatterError;

  /// The Markdown body (everything after the frontmatter).
  final String body;

  /// The body split into lines.
  final List<String> bodyLines;

  /// The 1-based line number in the manifest where the body starts.
  final int bodyStartLine;

  /// 1-based line of the `name:` key in the manifest, when present.
  final int? nameLine;

  /// 1-based line of the `description:` key in the manifest, when present.
  final int? descriptionLine;

  /// Files discovered under `references/`.
  final List<SideFile> references;

  /// Files discovered under `examples/`.
  final List<SideFile> examples;

  /// Files discovered under `scripts/`.
  final List<SideFile> scripts;

  /// Files discovered under `assets/`.
  final List<SideFile> assets;

  /// Non-fatal warnings emitted while reading the skill folder
  /// (e.g. unreadable side files).
  final List<String> parseWarnings;

  /// The skill `name` from frontmatter, when present and non-empty.
  String? get name {
    final value = frontmatter['name'];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// The skill `description` from frontmatter, when present and non-empty.
  String? get description {
    final value = frontmatter['description'];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// A display name for reporting: the frontmatter name when present,
  /// otherwise the skill folder name.
  String get displayName => name ?? _folderName;

  String get _folderName {
    final parts =
        skillRoot.replaceAll('\\', '/').split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? skillRoot : parts.last;
  }

  /// Converts a 0-based index into [bodyLines] to a 1-based manifest line.
  int bodyLineNumber(int bodyLineIndex) => bodyStartLine + bodyLineIndex;

  /// Whether the skill ships scripts or the body contains terminal or
  /// infrastructure commands. Category G applies only when this is true.
  bool get hasScriptsOrCommands {
    if (scripts.isNotEmpty) return true;
    if (body.contains('scripts/')) return true;
    final fence = RegExp(r'^\s*```(bash|sh|shell|zsh|powershell|console)\b',
        multiLine: true);
    if (fence.hasMatch(body)) return true;
    final dollar = RegExp(r'^\s*\$\s+\S', multiLine: true);
    return dollar.hasMatch(body);
  }

  /// Body lines with fenced code blocks blanked out, preserving line
  /// numbering. Useful for prose-only heuristics.
  List<String> get proseLines {
    final result = <String>[];
    var inFence = false;
    for (final line in bodyLines) {
      if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) {
        inFence = !inFence;
        result.add('');
        continue;
      }
      result.add(inFence ? '' : line);
    }
    return result;
  }
}
