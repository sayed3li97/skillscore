---
name: pdf-form-filler
description: >-
  Fills PDF form fields from structured JSON data and writes a flattened
  output file. Use when the user asks to fill, complete, or populate a PDF
  form programmatically. Do not use for scanned or image-only PDFs, and not
  for creating new PDF layouts from scratch.
---

# PDF form filler

Fill AcroForm fields in an existing PDF from a JSON mapping and produce a
flattened copy. Read [field mapping reference](references/field-mapping.md)
when the form uses radio groups or nested field names.

## Workflow

1. Inspect the form fields: run `python scripts/fill.py --list input.pdf`.
2. Build the JSON mapping of field name to value.
3. Fill the form: `python scripts/fill.py input.pdf mapping.json out.pdf`.
4. Validate the output: re-run with `--list out.pdf` and confirm every
   required field is populated; if any field is empty, fix the mapping and
   repeat until the validation passes.

```bash
python scripts/fill.py taxform.pdf mapping.json filled.pdf
```

```json
{ "applicant_name": "Jane Doe", "filing_year_choice": "single" }
```

## Anti-patterns

- Do not overwrite the input PDF; always write to a new output path.
- Never guess field names — list them first.
- Avoid flattening when the user explicitly asks for an editable result.

## Safety

`scripts/fill.py` only reads the input PDF and writes the named output
file; it touches nothing else on disk and never makes network calls. The
agent should execute it (not merely read it). Arguments: input path, JSON
mapping path, output path; `--list` prints field names instead of writing.
