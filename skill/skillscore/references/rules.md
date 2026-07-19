# skillscore rubric reference

The rule ids you can pass to `skillscore explain <rule-id>`, grouped by
category. Run `skillscore rules` for the live table from your installed version.

## Contents

- [A. Frontmatter validity](#a-frontmatter-validity)
- [B. Description quality](#b-description-quality)
- [C. Conciseness and token economy](#c-conciseness-and-token-economy)
- [D. Structure and progressive disclosure](#d-structure-and-progressive-disclosure)
- [E. Instruction quality](#e-instruction-quality)
- [F. Content hygiene](#f-content-hygiene)
- [G. Safety and scripts](#g-safety-and-scripts)

## A. Frontmatter validity

- `A1_frontmatter_present` — YAML frontmatter delimited by `---`.
- `A2_name_format` — `name` at most 64 chars, lowercase, digits, hyphens.
- `A3_name_reserved_words` — `name` avoids reserved vendor words.
- `A4_description_present` — `description` present, at most 1024 chars.
- `A5_frontmatter_keys` — only recognized keys, with a "did you mean" hint.

## B. Description quality

- `B1_description_what` — states WHAT the skill does (opens with an action verb).
- `B2_description_when` — states WHEN to use it ("use when ...").
- `B3_third_person` — written in third person.
- `B4_frontloaded_triggers` — concrete keywords in the first characters.
- `B5_boundary_clause` — has a "do not use" boundary.
- `B6_description_truncation` — self-contained within the routing window.

## C. Conciseness and token economy

- `C1_body_length` — body stays within the recommended line budget.
- `C2_explainer_bloat` — no definitions of common knowledge.
- `C3_excessive_optionality` — no long "or" chains.

## D. Structure and progressive disclosure

- `D1_progressive_disclosure` — depth split into references and examples.
- `D2_one_level_links` — reference links stay one level deep.
- `D3_reference_toc` — long reference files carry a table of contents.

## E. Instruction quality

- `E1_anti_patterns` — states anti-patterns explicitly.
- `E2_workflow_checklist` — a checklist or numbered workflow.
- `E3_feedback_loop` — a validate, fix, repeat loop.
- `E4_code_example` — at least one fenced code example.

## F. Content hygiene

- `F1_time_sensitive` — no date-anchored statements that rot.
- `F2_forward_slashes` — paths use forward slashes only.
- `F3_consistent_terminology` — no synonym mixing.

## G. Safety and scripts

- `G1_safety_section` — skills that ship scripts or commands need a Safety section.
- `G2_script_docs` — bundled scripts are documented.
