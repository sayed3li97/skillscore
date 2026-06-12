// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import '../model/skill_document.dart';
import 'rule.dart';

/// A1: the manifest exists and opens with `---` delimited YAML
/// frontmatter. Source: Anthropic, Antigravity, and Codex guides.
class FrontmatterPresentRule extends BaseRule {
  @override
  String get id => 'A1_frontmatter_present';
  @override
  String get title => 'Manifest has YAML frontmatter delimited by ---';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.error;
  @override
  String get rationale =>
      'Agents read only the frontmatter name and description at startup. '
      'Without a valid --- delimited YAML block the skill is invisible to '
      'every agent. All three official guides require it.';
  @override
  String get fixHint =>
      'Start the file with "---", add "name:" and "description:" keys, and '
      'close the block with another "---" line.';

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    if (doc.hasFrontmatterDelimiters && doc.frontmatterValid) return pass();
    if (!doc.hasFrontmatterDelimiters) {
      return fail([
        finding(
          'No YAML frontmatter found: the file must open with a "---" '
          'delimited block.',
          line: 1,
        ),
      ]);
    }
    return fail([
      finding(
        doc.frontmatterError ?? 'Frontmatter could not be parsed as YAML.',
        line: 1,
      ),
    ]);
  }
}

/// A2: `name` is present, at most 64 characters, and uses only
/// lowercase letters, numbers, and hyphens. Source: Anthropic,
/// Antigravity.
class NameFormatRule extends BaseRule {
  @override
  String get id => 'A2_name_format';
  @override
  String get title => 'name is <=64 chars of lowercase letters/digits/hyphens';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.error;
  @override
  String get rationale =>
      'Skill names are machine identifiers. Anthropic and Antigravity both '
      'restrict them to lowercase letters, numbers, and hyphens, at most 64 '
      'characters, so agents can address skills consistently.';
  @override
  String get fixHint =>
      'Rename the skill to lowercase-hyphenated form, e.g. "pdf-form-filler", '
      'and keep it at 64 characters or fewer.';

  static final RegExp _valid = RegExp(r'^[a-z0-9-]+$');

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final name = doc.name;
    if (name == null) {
      return fail([
        finding('Frontmatter has no "name" key.', line: doc.nameLine ?? 1),
      ]);
    }
    final problems = <Finding>[];
    if (name.length > 64) {
      problems.add(finding(
        '"name" is ${name.length} characters; the limit is 64.',
        line: doc.nameLine,
      ));
    }
    if (!_valid.hasMatch(name)) {
      problems.add(finding(
        '"name" may contain only lowercase letters, numbers, and hyphens '
        '(found "$name").',
        line: doc.nameLine,
      ));
    }
    return problems.isEmpty ? pass() : fail(problems);
  }
}

/// A3: `name` avoids the reserved words `anthropic` and `claude`.
/// ERROR for the claude target, INFO elsewhere. Source: Anthropic.
class NameReservedWordsRule extends BaseRule {
  @override
  String get id => 'A3_name_reserved_words';
  @override
  String get title => 'name avoids reserved words "anthropic" and "claude"';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 3;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.error;
  @override
  String get rationale =>
      'Anthropic reserves "anthropic" and "claude" in skill names; skills '
      'using them can be rejected or shadowed on Claude platforms.';
  @override
  String get fixHint =>
      'Remove "anthropic"/"claude" from the name and describe the task '
      'instead, e.g. "code-reviewer" rather than "claude-reviewer".';

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final name = doc.name;
    if (name == null) {
      // A2 already reports the missing name; award nothing extra here.
      return const RuleResult(points: 0);
    }
    final lower = name.toLowerCase();
    final hits = ['anthropic', 'claude'].where(lower.contains).toList();
    if (hits.isEmpty) return pass();
    return fail([
      finding(
        '"name" contains reserved word(s): ${hits.join(', ')}.',
        line: doc.nameLine,
      ),
    ]);
  }
}

/// A4: `description` is present, non-empty, and at most 1024
/// characters. Source: Anthropic.
class DescriptionPresentRule extends BaseRule {
  @override
  String get id => 'A4_description_present';
  @override
  String get title => 'description is present, non-empty, and <=1024 chars';
  @override
  String get sourceGuide => 'Anthropic';
  @override
  int get maxPoints => 4;
  @override
  Set<Target> get targets => Target.values.toSet();
  @override
  Severity get defaultSeverity => Severity.error;
  @override
  String get rationale =>
      'The description is the only text agents see before deciding to load '
      'the skill. A missing or oversized description breaks discovery or '
      'wastes permanent context budget.';
  @override
  String get fixHint =>
      'Add a "description:" key of at most 1024 characters stating what the '
      'skill does and when to use it.';

  @override
  RuleResult evaluate(SkillDocument doc, Target target) {
    final description = doc.description;
    if (description == null) {
      return fail([
        finding(
          'Frontmatter has no non-empty "description" key.',
          line: doc.descriptionLine ?? 1,
        ),
      ]);
    }
    if (description.length > 1024) {
      return fail([
        finding(
          '"description" is ${description.length} characters; the limit '
          'is 1024.',
          line: doc.descriptionLine,
        ),
      ]);
    }
    return pass();
  }
}
