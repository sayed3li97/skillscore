// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skillscore/skillscore.dart';

/// Parses inline [content] as a manifest in a throwaway location.
SkillDocument parseDoc(String content, {String path = '/virtual/SKILL.md'}) =>
    SkillParser().parseContent(content, manifestPath: path);

/// A minimal valid manifest with [body] appended after the frontmatter.
String manifestWith({
  String name = 'sample-skill',
  String? description =
      'Generates sample output. Use when the user asks for samples. '
          'Do not use for real data.',
  String body = '',
}) {
  final descriptionLine =
      description == null ? '' : 'description: $description\n';
  return '---\nname: $name\n$descriptionLine---\n$body';
}

/// Creates a temp skill folder, writes [files] (relative path -> content),
/// runs [fn] with the folder path, and cleans up afterwards.
T inTempSkill<T>(Map<String, String> files, T Function(String root) fn) {
  final dir = Directory.systemTemp.createTempSync('skillscore_test_');
  try {
    files.forEach((rel, content) {
      final file = File(p.join(dir.path, rel));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    });
    return fn(dir.path);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Evaluates [rule] against inline manifest [content] for [target].
RuleResult evaluate(Rule rule, String content,
        {Target target = Target.universal}) =>
    rule.evaluate(parseDoc(content), target);

/// Path to the committed end-to-end fixtures.
String fixture(String relative) => p.join('test', 'fixtures', relative);
