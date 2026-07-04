// SPDX-License-Identifier: Apache-2.0

import '../model/finding.dart';
import 'conciseness_rules.dart';
import 'description_rules.dart';
import 'frontmatter_rules.dart';
import 'hygiene_rules.dart';
import 'instruction_rules.dart';
import 'rule.dart';
import 'safety_rules.dart';
import 'structure_rules.dart';

/// Human-readable names for the rubric categories.
const Map<String, String> categoryNames = {
  'A': 'Frontmatter validity',
  'B': 'Description quality',
  'C': 'Conciseness & token economy',
  'D': 'Structure & progressive disclosure',
  'E': 'Instruction quality',
  'F': 'Content hygiene',
  'G': 'Safety & scripts',
};

/// The maximum combined category-G penalty.
const int safetyPenaltyCap = -15;

/// Central registry of every rule and the per-target profiles.
///
/// Target selection is data, not conditionals: a rule is active for a
/// target when the target is in `rule.targets`, and its effective
/// severity comes from [severityOverrides] (falling back to the rule's
/// default).
class RuleRegistry {
  /// Creates a registry with the built-in rule set.
  RuleRegistry() : rules = List.unmodifiable(_builtinRules());

  /// All registered rules, in rubric order (A1..G2).
  final List<Rule> rules;

  static List<Rule> _builtinRules() => [
        FrontmatterPresentRule(),
        NameFormatRule(),
        NameReservedWordsRule(),
        DescriptionPresentRule(),
        FrontmatterKeysRule(),
        DescriptionWhatRule(),
        DescriptionWhenRule(),
        ThirdPersonRule(),
        FrontloadedTriggersRule(),
        BoundaryClauseRule(),
        DescriptionTruncationRule(),
        BodyLengthRule(),
        ExplainerBloatRule(),
        ExcessiveOptionalityRule(),
        ProgressiveDisclosureRule(),
        OneLevelLinksRule(),
        ReferenceTocRule(),
        AntiPatternsRule(),
        WorkflowChecklistRule(),
        FeedbackLoopRule(),
        CodeExampleRule(),
        TimeSensitiveRule(),
        ForwardSlashesRule(),
        ConsistentTerminologyRule(),
        SafetySectionRule(),
        ScriptDocsRule(),
      ];

  /// Per-target severity overrides (rule id -> severity).
  ///
  /// A3 is an ERROR only on the claude target (Anthropic reserves the
  /// words); everywhere else the guides treat it as advisory, and the
  /// universal profile takes the most lenient severity. B5 is required
  /// (WARNING) on antigravity, advisory (INFO) elsewhere.
  static const Map<Target, Map<String, Severity>> severityOverrides = {
    Target.claude: {},
    Target.antigravity: {
      'A3_name_reserved_words': Severity.info,
      'B5_boundary_clause': Severity.warning,
    },
    Target.codex: {
      'A3_name_reserved_words': Severity.info,
    },
    Target.universal: {
      'A3_name_reserved_words': Severity.info,
    },
  };

  /// Rules active for [target], in stable rubric order.
  List<Rule> activeRules(Target target) =>
      rules.where((r) => r.targets.contains(target)).toList();

  /// The effective severity of [rule] under [target].
  Severity effectiveSeverity(Rule rule, Target target) =>
      severityOverrides[target]?[rule.id] ?? rule.defaultSeverity;

  /// Looks up a rule by id (exact match), or `null`.
  Rule? byId(String id) {
    for (final rule in rules) {
      if (rule.id == id || rule.id.split('_').first == id) return rule;
    }
    return null;
  }
}
