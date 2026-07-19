// SPDX-License-Identifier: Apache-2.0
//
// Entry point for the browser playground. It wires the page's textarea and
// guide selector to the real skillscore scorer (the same rule engine as the
// CLI, compiled to JavaScript), and renders the scorecard. Everything runs
// locally in the browser; nothing is uploaded.
//
// dart:html is the simplest, dependency-free DOM API for a dart2js target and
// still fully supported by the compiler; the deprecation notice is expected.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:skillscore/skillscore_web.dart';

// Built once and reused: the registry is stateless and the token counter
// caches its BPE tables after the first call.
final RuleRegistry _registry = RuleRegistry();
final TokenCounter _tokenCounter = TokenCounter();

late TextAreaElement _input;
late SelectElement _target;
late Element _results;

Timer? _debounce;

const String _sample = '''---
name: pdf-form-filler
description: Fills interactive PDF form fields from structured data. Use when the user asks to fill, populate, or complete a PDF form from a CSV or JSON file. Do not use for scanned or image-only PDFs.
license: Apache-2.0
---

# PDF form filler

Fill the fields of an interactive PDF from a data file, then save a copy.

## Workflow

1. Read the data file (CSV or JSON) the user points at.
2. Map each column or key to a form field name in the PDF.
3. Write the values and save a new copy; never overwrite the original.
4. Report which fields were filled and which were left blank.

## Example

```bash
python scripts/fill.py --template form.pdf --data rows.csv --out filled.pdf
```

## Anti-patterns

- Do not flatten the form unless the user asks; keep fields editable.
- Do not guess a mapping; if a column has no field, report it.

## Safety

Only reads the input files and writes a new PDF. Never edits the source file
in place, and makes no network calls.
''';

void main() {
  _input = querySelector('#input') as TextAreaElement;
  _target = querySelector('#target') as SelectElement;
  _results = querySelector('#results')!;

  _input.onInput.listen((_) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _scoreNow);
  });
  _target.onChange.listen((_) => _scoreNow());
  (querySelector('#sample') as ButtonElement).onClick.listen((_) {
    _input.value = _sample;
    _scoreNow();
  });
  (querySelector('#share') as ButtonElement).onClick.listen((_) => _share());

  final restored = _decodeHash();
  if (restored != null && restored.isNotEmpty) {
    _input.value = restored;
  }
  _scoreNow();
}

void _scoreNow() {
  final text = _input.value ?? '';
  if (text.trim().isEmpty) {
    _results
      ..children.clear()
      ..append(DivElement()
        ..className = 'empty'
        ..text = 'Paste a SKILL.md on the left to see its score.');
    return;
  }
  final target =
      targetFromName(_target.value ?? 'universal') ?? Target.universal;
  final doc = parseSkillContent(text, manifestPath: 'SKILL.md');
  final result =
      Scorer(_registry, tokenCounter: _tokenCounter).score(doc, target);
  _render(result);
}

String _gradeColorVar(String grade) {
  switch (grade) {
    case 'A':
      return 'var(--a)';
    case 'B':
      return 'var(--b)';
    case 'C':
      return 'var(--c)';
    case 'D':
      return 'var(--d)';
    default:
      return 'var(--f)';
  }
}

String _ratioColorVar(double ratio) {
  if (ratio >= 0.9) return 'var(--a)';
  if (ratio >= 0.7) return 'var(--b)';
  if (ratio >= 0.5) return 'var(--c)';
  return 'var(--d)';
}

void _render(ScoreResult r) {
  final root = DocumentFragment();

  // Scorecard: badge + meta.
  final badge = DivElement()..className = 'badge';
  badge.style.borderColor = _gradeColorVar(r.grade);
  badge.append(DivElement()
    ..className = 'num'
    ..text = '${r.score}');
  badge.append(DivElement()
    ..className = 'grade'
    ..text = 'grade ${r.grade}');

  final meta = DivElement()..className = 'scoremeta';
  meta.append(Element.tag('h2')
    ..append(SpanElement()
      ..className = 'name'
      ..text = r.doc.displayName));
  meta.append(DivElement()
    ..className = 'sub'
    ..text = '${r.score}/100 · ${_target.value} guide');

  root.append(DivElement()
    ..className = 'scorecard'
    ..append(badge)
    ..append(meta));

  // Categories.
  root.append(DivElement()
    ..className = 'section-title'
    ..text = 'Rubric');
  for (final c in r.categories) {
    final row = DivElement()..className = 'cat';
    row.append(DivElement()
      ..className = 'clabel'
      ..text = '${c.category}  ${c.name}');
    if (c.max > 0) {
      final ratio = (c.awarded / c.max).clamp(0.0, 1.0);
      row.append(DivElement()
        ..className = 'cpts'
        ..text = '${_num(c.awarded)}/${c.max}');
      final bar = DivElement()..className = 'bar';
      final fill = SpanElement()..style.width = '${(ratio * 100).round()}%';
      fill.style.background = _ratioColorVar(ratio);
      row.append(bar..append(fill));
    } else {
      // Category G: a penalty, not a scored maximum.
      row.append(DivElement()
        ..className = 'cpts'
        ..text = c.awarded == 0 ? 'ok' : _num(c.awarded));
      row.append(DivElement()
        ..className = 'clabel'
        ..style.color = c.awarded == 0 ? 'var(--muted)' : 'var(--f)'
        ..text = c.awarded == 0 ? 'no penalty' : 'penalty applied');
    }
    root.append(row);
  }

  // Tokens.
  final t = r.tokenCounts;
  if (t != null) {
    root.append(DivElement()
      ..className = 'section-title'
      ..text = 'Token budget');
    final tok = DivElement()..className = 'tokens';
    tok.append(_tokenSpan('description (every prompt)',
        '${t.descriptionCl100k} gpt-4 · ~${t.descriptionClaude} claude'));
    tok.append(_tokenSpan('full manifest (when invoked)',
        '${t.manifestCl100k} gpt-4 · ~${t.manifestClaude} claude'));
    root.append(tok);
  }

  // Findings.
  final findings = r.findings;
  root.append(DivElement()
    ..className = 'section-title'
    ..text = findings.isEmpty ? 'Findings' : 'Findings (${findings.length})');
  if (findings.isEmpty) {
    root.append(DivElement()
      ..className = 'clean'
      ..text = 'No findings. Nice work.');
  } else {
    for (final f in findings) {
      root.append(_findingCard(f));
    }
  }

  _results
    ..children.clear()
    ..append(root);
}

Element _tokenSpan(String label, String value) {
  final span = SpanElement()..text = '$label: ';
  span.append(Element.tag('b')..text = value);
  return span;
}

Element _findingCard(Finding f) {
  final card = DivElement()..className = 'finding ${f.severity.name}';

  final top = DivElement()..className = 'top';
  top.append(SpanElement()
    ..className = 'rule'
    ..text = f.ruleId);
  top.append(SpanElement()
    ..className = 'sev'
    ..text = f.severity.name);
  if (f.line != null) {
    top.append(SpanElement()
      ..className = 'loc'
      ..text = 'line ${f.line}');
  }
  top.append(SpanElement()
    ..className = 'loc'
    ..text = f.sourceGuide);
  card.append(top);

  card.append(DivElement()
    ..className = 'msg'
    ..text = f.message);

  final fix = DivElement()..className = 'fix';
  fix.append(Element.tag('b')..text = 'fix: ');
  fix.appendText(f.fixHint);
  card.append(fix);
  return card;
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// --- shareable permalink (base64url of UTF-8, in the URL fragment) ---

void _share() {
  final text = _input.value ?? '';
  final encoded = base64Url.encode(utf8.encode(text));
  final url = '${window.location.origin}${window.location.pathname}#s=$encoded';
  window.history.replaceState(null, '', url);
  window.navigator.clipboard?.writeText(url);
  _toast('Link copied');
}

String? _decodeHash() {
  final hash = window.location.hash;
  if (!hash.startsWith('#s=')) return null;
  try {
    return utf8.decode(base64Url.decode(hash.substring(3)));
  } catch (_) {
    return null;
  }
}

void _toast(String message) {
  final el = querySelector('#toast')!;
  el
    ..text = message
    ..classes.add('show');
  Timer(const Duration(milliseconds: 1400), () => el.classes.remove('show'));
}
