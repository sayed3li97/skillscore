// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import '../model/skill_document.dart';
import 'eval_document.dart';
import 'eval_query.dart';

/// Generates a ready-to-run `evals.json` from a parsed [SkillDocument].
///
/// The scaffolder derives trigger queries from the skill's trigger clause
/// and non-trigger queries from its boundary clause (when present). All
/// generated queries are real English sentences — not placeholders — so the
/// file is runnable immediately while still being easy to extend.
class EvalScaffolder {
  /// Creates a const scaffolder instance.
  const EvalScaffolder();

  /// Returns a scaffolded [EvalDocument] for [skill].
  EvalDocument scaffold(SkillDocument skill) {
    final name = skill.name ?? skill.displayName;
    final description = skill.description ?? '';
    final queries = _generateQueries(name, description);
    return EvalDocument(
      skillName: name,
      queries: queries,
    );
  }

  /// Returns the scaffolded [EvalDocument] as a formatted JSON string.
  String generate(SkillDocument skill) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(scaffold(skill).toJson());
  }

  // ---------------------------------------------------------------------------
  // Query generation
  // ---------------------------------------------------------------------------

  List<EvalQuery> _generateQueries(String name, String description) {
    final triggerContext = _extractTriggerContext(description);
    final boundaryContext = _extractBoundaryContext(description);
    final whatContext = _extractWhatContext(description);

    final trigger = _buildTriggerQueries(name, triggerContext, whatContext);
    final nonTrigger =
        _buildNonTriggerQueries(name, boundaryContext, whatContext);

    // Assign stable IDs and interleave trigger/non-trigger for readability.
    final queries = <EvalQuery>[];
    for (var i = 0; i < trigger.length; i++) {
      queries.add(EvalQuery(
          id: 't${(i + 1).toString().padLeft(2, '0')}',
          query: trigger[i],
          shouldTrigger: true));
    }
    for (var i = 0; i < nonTrigger.length; i++) {
      queries.add(EvalQuery(
          id: 'n${(i + 1).toString().padLeft(2, '0')}',
          query: nonTrigger[i],
          shouldTrigger: false));
    }
    return queries;
  }

  // ---------------------------------------------------------------------------
  // Context extraction from the description
  // ---------------------------------------------------------------------------

  /// Extracts the primary action phrase (verb + object) from the first sentence.
  _WhatContext _extractWhatContext(String description) {
    if (description.isEmpty) return const _WhatContext('use', 'this skill');

    final first = description.split(RegExp(r'[.!?]')).first.trim();
    // Find the action verb (first known verb in the sentence).
    final words =
        first.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String verb = 'use';
    int verbIndex = 0;
    for (var i = 0; i < words.length; i++) {
      final w = words[i].toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (_actionVerbs.contains(w) || _actionVerbs.contains(_stem(w))) {
        verb = w;
        verbIndex = i;
        break;
      }
    }
    // Everything after the verb is the "object".
    final object = verbIndex + 1 < words.length
        ? words.sublist(verbIndex + 1).join(' ')
        : 'the requested task';
    return _WhatContext(verb, _trim(object, 60));
  }

  /// Extracts trigger conditions from "Use when ...", "when the user ..." etc.
  _TriggerContext _extractTriggerContext(String description) {
    final triggerRegex = RegExp(
      r'\b(use (?:this skill |this |it )?when|when the user|when a user|'
      r'when you need|use (?:this |it )?for|use (?:this skill |this |it )?if|'
      r'triggers? when|applies when|invoke (?:this |it )?when)\b'
      r'(?:\s+(?:the user )?(?:asks? (?:to |you to |for )?)?)?(.+?)(?:[;.]|$)',
      caseSensitive: false,
    );
    final m = triggerRegex.firstMatch(description);
    if (m != null) {
      final condition = m.group(2)?.trim() ?? '';
      if (condition.isNotEmpty) {
        return _TriggerContext(_trim(condition, 80));
      }
    }
    return const _TriggerContext('');
  }

  /// Extracts "do not use for" boundary conditions.
  _BoundaryContext _extractBoundaryContext(String description) {
    final boundaryRegex = RegExp(
      r"\b(?:do not use|don't use|not for|does not (?:handle|support)|"
      r'not intended for|not suitable for|avoid using)\b'
      r'\s+(?:for\s+)?(.+?)(?:[;.]|$)',
      caseSensitive: false,
    );
    final m = boundaryRegex.firstMatch(description);
    if (m != null) {
      final cond = m.group(1)?.trim() ?? '';
      if (cond.isNotEmpty) return _BoundaryContext(_trim(cond, 80));
    }
    return const _BoundaryContext('');
  }

  // ---------------------------------------------------------------------------
  // Query builders
  // ---------------------------------------------------------------------------

  List<String> _buildTriggerQueries(
      String name, _TriggerContext trigger, _WhatContext what) {
    final verb = what.verb;
    final obj = what.object;
    final cond = trigger.condition;

    // Canonical forms that cover different user phrasings.
    final queries = <String>[];

    // Direct imperative (most common in real conversations).
    queries.add('${_capitalize(verb)} $obj');

    // User states their intent.
    queries.add('I need to $verb $obj');

    // Framing as a task for the agent.
    if (cond.isNotEmpty) {
      queries.add('${_capitalize(verb)} $obj. ${_capitalize(cond)}');
    } else {
      queries.add('Can you $verb $obj for me?');
    }

    // Contextual: "when" phrasing (matches the trigger clause directly).
    if (cond.isNotEmpty) {
      queries.add('Help me when I need to $cond');
    } else {
      queries.add('Please $verb $obj now');
    }

    // Agent delegation phrasing.
    queries.add('Use the $name skill to $verb $obj');

    // Variations on the verb.
    queries.add('${_capitalize(_synonymVerb(verb))} $obj');
    queries.add('I want to $verb $obj');
    queries.add('${_capitalize(verb)} $obj automatically');
    queries.add('The user wants to $verb $obj');
    queries.add('Apply the $name skill: $verb $obj');

    return queries.take(10).toList();
  }

  List<String> _buildNonTriggerQueries(
      String name, _BoundaryContext boundary, _WhatContext what) {
    final obj = what.object;
    final excluded = boundary.condition;

    final queries = <String>[];

    // Boundary-derived: the thing the skill explicitly excludes.
    if (excluded.isNotEmpty) {
      queries.add('I need help with $excluded');
      queries.add('Can you handle $excluded for me?');
      queries.add('${_capitalize(excluded)} — please assist');
    }

    // Generic out-of-scope tasks that the agent should handle differently.
    queries.add('What is $obj? Explain it to me.');
    queries.add('Tell me the history of $obj.');
    queries.add('Summarise the documentation for $obj');
    queries.add('Debug why $obj is not working as expected');
    queries.add('How do I install the dependency for $obj?');
    queries.add('Write a unit test for $obj');
    queries.add('What are the alternatives to $obj?');

    // Unrelated queries to verify the skill does not over-trigger.
    queries.add('Book a meeting for tomorrow afternoon');
    queries.add('What is the weather like today?');

    return queries.take(10).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _trim(String s, int maxLen) =>
      s.length <= maxLen ? s : '${s.substring(0, maxLen - 3)}...';

  static String _stem(String word) {
    if (word.endsWith('ing')) return word.substring(0, word.length - 3);
    if (word.endsWith('es')) return word.substring(0, word.length - 2);
    if (word.endsWith('s')) return word.substring(0, word.length - 1);
    return word;
  }

  static String _synonymVerb(String verb) {
    const synonyms = {
      'generate': 'produce',
      'create': 'build',
      'build': 'create',
      'convert': 'transform',
      'transform': 'convert',
      'analyze': 'inspect',
      'validate': 'check',
      'check': 'verify',
      'verify': 'validate',
      'format': 'reformat',
      'fill': 'complete',
      'complete': 'fill',
      'process': 'handle',
      'handle': 'process',
    };
    return synonyms[verb] ?? verb;
  }

  static const Set<String> _actionVerbs = {
    'analyze',
    'audit',
    'build',
    'check',
    'compile',
    'convert',
    'create',
    'debug',
    'deploy',
    'detect',
    'draft',
    'evaluate',
    'export',
    'extract',
    'fill',
    'find',
    'fix',
    'format',
    'generate',
    'identify',
    'implement',
    'import',
    'lint',
    'manage',
    'migrate',
    'parse',
    'plan',
    'process',
    'produce',
    'refactor',
    'render',
    'report',
    'review',
    'run',
    'scan',
    'score',
    'search',
    'summarize',
    'sync',
    'test',
    'transform',
    'translate',
    'update',
    'validate',
    'verify',
    'write',
  };
}

// ---------------------------------------------------------------------------
// Internal value types
// ---------------------------------------------------------------------------

class _WhatContext {
  const _WhatContext(this.verb, this.object);
  final String verb;
  final String object;
}

class _TriggerContext {
  const _TriggerContext(this.condition);
  final String condition;
}

class _BoundaryContext {
  const _BoundaryContext(this.condition);
  final String condition;
}
