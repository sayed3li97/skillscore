// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

final RegExp _mdLink = RegExp(r'\[[^\]]*\]\(([^)#][^)]*)\)');

List<String> _localMarkdownLinks(String text) {
  final links = <String>[];
  for (final m in _mdLink.allMatches(text)) {
    final href = m.group(1)!.trim();
    if (href.contains('://') || href.startsWith('mailto:')) continue;
    final clean = href.split('#').first;
    if (clean.toLowerCase().endsWith('.md')) links.add(clean);
  }
  return links;
}

/// D1: long skills split depth into `references/` or `examples/`
/// instead of one giant file. Source: Anthropic, Antigravity.
class ProgressiveDisclosureRule extends BaseRule {
  @override
  String get id => 'D1_progressive_disclosure';
  @override
  String get title => 'Depth is split into references/ or examples/';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 5;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.info;
  @override
  String get rationale =>
      'Progressive disclosure keeps the always-loaded manifest small: '
      'agents read side files only when needed. One giant SKILL.md defeats '
      'that design.';
  @override
  String get fixHint =>
      'Move detailed reference material into references/ (and worked '
      'examples into examples/), linking to them from the manifest.';

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    if (doc.bodyLines.length <= 150) return pass();
    final hasSideContent = doc.references.isNotEmpty || doc.examples.isNotEmpty;
    final hasLocalLinks = _localMarkdownLinks(doc.body).isNotEmpty;
    if (hasSideContent || hasLocalLinks) return pass();
    return fail([
      finding(
        'Body is ${doc.bodyLines.length} lines with no references/ or '
        'examples/ split.',
        line: doc.bodyLineNumber(150),
      ),
    ]);
  }
}

/// D2: reference links are one level deep from the manifest — no
/// nested chains. Source: Anthropic.
class OneLevelLinksRule extends BaseRule {
  @override
  String get id => 'D2_one_level_links';
  @override
  String get title => 'Reference links are one level deep';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 5;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.warning;
  @override
  String get rationale =>
      'Agents reliably follow one hop from the manifest. Content hidden two '
      'links away (SKILL.md -> a.md -> b.md) is effectively unreachable.';
  @override
  String get fixHint =>
      'Inline the second-level file into the first, or link it directly '
      'from the manifest.';

  /// Scoring: each nested chain costs 2.5 points:
  /// `points = max(0, 5 - 2.5 * chains)`.
  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final findings = <Finding>[];
    final seen = <String>{};
    for (var i = 0; i < doc.bodyLines.length; i++) {
      for (final link in _localMarkdownLinks(doc.bodyLines[i])) {
        final targetPath = p.normalize(p.join(doc.skillRoot, link));
        if (!seen.add(targetPath)) continue;
        final file = File(targetPath);
        if (!file.existsSync()) continue;
        String content;
        try {
          content = file.readAsStringSync();
        } on FileSystemException {
          continue;
        }
        final onward = _localMarkdownLinks(content);
        if (onward.isNotEmpty) {
          findings.add(finding(
            '"$link" links onward to ${onward.first} — content is two '
            'levels deep from the manifest.',
            line: doc.bodyLineNumber(i),
          ));
        }
      }
    }
    if (findings.isEmpty) return pass();
    final points = (5 - 2.5 * findings.length).clamp(0, 5).toDouble();
    return RuleResult(points: points, findings: findings);
  }
}

/// D3: long `references/` or `examples/` files start with a table of
/// contents. Source: Anthropic.
class ReferenceTocRule extends BaseRule {
  @override
  String get id => 'D3_reference_toc';
  @override
  String get title => 'Long reference files have a table of contents';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 5;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.info;
  @override
  String get rationale =>
      'A table of contents lets the agent jump to the relevant section of a '
      'long reference file instead of reading (and paying for) all of it.';
  @override
  String get fixHint =>
      'Add a "## Contents" section with anchor links near the top of every '
      'reference file longer than 100 lines.';

  static final RegExp _tocHeading =
      RegExp(r'^#{1,3}\s*(table of )?contents\b', caseSensitive: false);
  static final RegExp _anchorLink = RegExp(r'\]\(#');

  /// Scoring: proportional — `points = 5 * compliant / longFiles`
  /// (full points when there are no long files).
  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final longFiles = [...doc.references, ...doc.examples]
        .where((f) =>
            f.lines != null &&
            f.lines!.length > 100 &&
            f.relativePath.toLowerCase().endsWith('.md'))
        .toList();
    if (longFiles.isEmpty) return pass();
    final findings = <Finding>[];
    var compliant = 0;
    for (final file in longFiles) {
      final head = file.lines!.take(30).toList();
      final hasToc = head.any(_tocHeading.hasMatch) ||
          head.where(_anchorLink.hasMatch).length >= 3;
      if (hasToc) {
        compliant++;
      } else {
        findings.add(finding(
          '${file.relativePath} is ${file.lines!.length} lines with no '
          'table of contents near the top.',
        ));
      }
    }
    if (findings.isEmpty) return pass();
    final points = (5 * compliant / longFiles.length).toDouble();
    return RuleResult(points: points, findings: findings);
  }
}
