#!/usr/bin/env node
// QA runner for `skillscore eval` — executes every test case, captures
// terminal output, renders each result as a PNG screenshot, and writes
// docs/qa/REPORT.md with a full test record.
//
// Usage: node tool/qa_run.mjs
// Prerequisites: skillscore binary on PATH, Chrome at the default macOS path.

import { execSync, spawnSync } from 'child_process';
import { mkdirSync, writeFileSync, rmSync, existsSync, readFileSync } from 'fs';
import { join, resolve } from 'path';
import { tmpdir } from 'os';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const REPO   = resolve(import.meta.dirname, '..');
const QA_DIR = join(REPO, 'docs', 'qa');
const EVD    = join(QA_DIR, 'evidence');

mkdirSync(EVD, { recursive: true });

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const EXCELLENT_MANIFEST = `---
name: pdf-form-filler
description: >-
  Fills PDF form fields from structured JSON data and writes a flattened
  output file. Use when the user asks to fill, complete, or populate a PDF
  form programmatically from a JSON data source. Do not use for scanned or
  image-only PDFs, and not for creating new PDF layouts from scratch.
version: "1.0"
authors:
  - name: QA Test
---

# PDF form filler

Fill AcroForm fields in an existing PDF from a JSON mapping and produce a
flattened copy.

## When to use

Use when the user needs to programmatically fill a PDF form from structured data.

## Safety

Never overwrite the source PDF. Always write to a new output path.
`;

const VALID_EVALS = `{
  "skill": "pdf-form-filler",
  "version": 1,
  "runs_per_query": 3,
  "trigger_threshold": 0.5,
  "queries": [
    {"id": "t01", "query": "Fill this PDF form with my JSON data", "should_trigger": true},
    {"id": "t02", "query": "I need to fill in a PDF form", "should_trigger": true},
    {"id": "t03", "query": "Complete the form fields in this PDF", "should_trigger": true},
    {"id": "t04", "query": "Populate this PDF with JSON values", "should_trigger": true},
    {"id": "t05", "query": "Fill the W-9 PDF form from the payload", "should_trigger": true},
    {"id": "n01", "query": "What is PDF form filling?", "should_trigger": false},
    {"id": "n02", "query": "Explain how PDF forms work", "should_trigger": false},
    {"id": "n03", "query": "Write a unit test for PDF form filling", "should_trigger": false},
    {"id": "n04", "query": "Book a meeting for tomorrow afternoon", "should_trigger": false},
    {"id": "n05", "query": "What is the weather like today?", "should_trigger": false}
  ]
}`;

const MINIMAL_EVALS = `{
  "skill": "pdf-form-filler",
  "version": 1,
  "queries": [
    {"query": "Fill this PDF", "should_trigger": true},
    {"query": "Print document", "should_trigger": false}
  ]
}`;

const MALFORMED_EVALS = `{ "skill": "x", broken json }`;

const TRIGGER_ONLY_EVALS = `{
  "skill": "pdf-form-filler",
  "queries": [
    {"query": "Fill this PDF", "should_trigger": true},
    {"query": "Complete the form", "should_trigger": true}
  ]
}`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeTempDir(name) {
  const dir = join(tmpdir(), `qa_${name}_${Date.now()}`);
  mkdirSync(dir, { recursive: true });
  return dir;
}

function writeFile(dir, name, content) {
  writeFileSync(join(dir, name), content);
}

function run(args, cwd) {
  const result = spawnSync('skillscore', args, {
    cwd: cwd ?? process.cwd(),
    encoding: 'utf8',
    timeout: 30000,
    env: { ...process.env, NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  return {
    exit: result.status ?? 2,
    stdout: (result.stdout ?? '').trim(),
    stderr: (result.stderr ?? '').trim(),
    combined: [result.stdout ?? '', result.stderr ?? ''].join('').trim(),
  };
}

// ---------------------------------------------------------------------------
// Terminal screenshot renderer
// ---------------------------------------------------------------------------

function buildHtml({ id, name, category, command, result, pass }) {
  const statusColor = pass ? '#3fb950' : '#f85149';
  const statusBg    = pass ? '#0d2119' : '#2d0f0f';
  const statusLabel = pass ? 'PASS' : 'FAIL';
  const exitColor   = result.exit === 0 ? '#3fb950'
                    : result.exit === 1 ? '#e3b341'
                    : '#f85149';

  const esc = s => s
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  const formatOutput = text => {
    if (!text) return '<span style="color:#484f58;font-style:italic">( no output )</span>';
    return esc(text)
      .split('\n')
      .map(line => {
        if (/^(error|Error):/.test(line))
          return `<span style="color:#f85149">${line}</span>`;
        if (/^warning:/.test(line))
          return `<span style="color:#e3b341">${line}</span>`;
        if (/PASS/.test(line))
          return `<span style="color:#3fb950">${line}</span>`;
        if (/FAIL/.test(line))
          return `<span style="color:#f85149">${line}</span>`;
        if (/✓/.test(line))
          return `<span style="color:#3fb950">${line}</span>`;
        if (/✗/.test(line))
          return `<span style="color:#f85149">${line}</span>`;
        if (/^  (skill|queries|runs|threshold|total|model)/.test(line))
          return `<span style="color:#8b949e">${line}</span>`;
        if (/passed.*failed/.test(line))
          return `<span style="color:#3fb950;font-weight:700">${line}</span>`;
        if (/^Created/.test(line))
          return `<span style="color:#3fb950">${line}</span>`;
        if (/^  Run:/.test(line))
          return `<span style="color:#79c0ff">${line}</span>`;
        if (/OK$/.test(line))
          return `<span style="color:#3fb950">${line}</span>`;
        return line;
      })
      .join('\n');
  };

  const stdout = formatOutput(result.stdout);
  const stderr = formatOutput(result.stderr);
  const hasStderr = result.stderr.length > 0;
  const hasStdout = result.stdout.length > 0;

  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #0d1117;
    font-family: ui-monospace, 'SF Mono', SFMono-Regular, Menlo, Consolas,
                 'Liberation Mono', monospace;
    font-size: 13px;
    line-height: 1.55;
    color: #e6edf3;
    padding: 0;
    min-width: 860px;
  }
  .card {
    background: #161b22;
    border: 1px solid #30363d;
    border-radius: 10px;
    overflow: hidden;
    margin: 24px;
  }
  .card-header {
    background: #0d1117;
    border-bottom: 1px solid #30363d;
    padding: 14px 20px;
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .badge-id {
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.06em;
    color: #79c0ff;
    background: #1c2d3f;
    border: 1px solid #1f6feb;
    border-radius: 5px;
    padding: 2px 9px;
    flex-shrink: 0;
  }
  .badge-cat {
    font-size: 11px;
    color: #8b949e;
    background: #21262d;
    border: 1px solid #30363d;
    border-radius: 5px;
    padding: 2px 9px;
    flex-shrink: 0;
  }
  .test-name {
    flex: 1;
    font-size: 14px;
    font-weight: 600;
    color: #f0f6fc;
    letter-spacing: -0.01em;
  }
  .badge-status {
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.08em;
    color: ${statusColor};
    background: ${statusBg};
    border: 1px solid ${statusColor};
    border-radius: 5px;
    padding: 2px 10px;
    flex-shrink: 0;
  }
  .section {
    padding: 14px 20px;
    border-bottom: 1px solid #21262d;
  }
  .section:last-child { border-bottom: none; }
  .section-label {
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: #484f58;
    margin-bottom: 8px;
  }
  .command-line {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .prompt { color: #3fb950; }
  .cmd { color: #e6edf3; }
  .terminal-out {
    background: #0d1117;
    border: 1px solid #21262d;
    border-radius: 6px;
    padding: 12px 14px;
    white-space: pre;
    overflow: hidden;
    font-size: 12.5px;
    line-height: 1.6;
  }
  .meta-row {
    display: flex;
    gap: 24px;
  }
  .meta-item { color: #8b949e; }
  .meta-item strong {
    color: #e6edf3;
    font-weight: 600;
    margin-right: 4px;
  }
  .exit-ok   { color: #3fb950; font-weight: 700; }
  .exit-fail { color: #f85149; font-weight: 700; }
  .exit-warn { color: #e3b341; font-weight: 700; }
</style>
</head>
<body>
<div class="card">
  <div class="card-header">
    <span class="badge-id">${esc(id)}</span>
    <span class="badge-cat">${esc(category)}</span>
    <span class="test-name">${esc(name)}</span>
    <span class="badge-status">${statusLabel}</span>
  </div>

  <div class="section">
    <div class="section-label">Command</div>
    <div class="command-line">
      <span class="prompt">$</span>
      <span class="cmd">${esc(command)}</span>
    </div>
  </div>

  <div class="section">
    <div class="meta-row">
      <div class="meta-item">
        <strong>Exit code</strong>
        <span class="${result.exit === 0 ? 'exit-ok' : result.exit === 1 ? 'exit-warn' : 'exit-fail'}">${result.exit}</span>
      </div>
      <div class="meta-item">
        <strong>stdout</strong>${hasStdout ? result.stdout.split('\n').length + ' lines' : 'empty'}
      </div>
      <div class="meta-item">
        <strong>stderr</strong>${hasStderr ? result.stderr.split('\n').length + ' lines' : 'empty'}
      </div>
    </div>
  </div>

  ${hasStdout ? `
  <div class="section">
    <div class="section-label">stdout</div>
    <div class="terminal-out">${stdout}</div>
  </div>` : ''}

  ${hasStderr ? `
  <div class="section">
    <div class="section-label">stderr</div>
    <div class="terminal-out">${stderr}</div>
  </div>` : ''}
</div>
</body>
</html>`;
}

async function screenshot(html, outPath) {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    headless: true,
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 900, height: 200, deviceScaleFactor: 2 });
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const el = await page.$('.card');
    const box = await el.boundingBox();
    await page.setViewport({
      width: 900,
      height: Math.ceil(box.height) + 48,
      deviceScaleFactor: 2,
    });
    await page.setContent(html, { waitUntil: 'networkidle0' });
    await page.screenshot({ path: outPath, fullPage: true });
  } finally {
    await browser.close();
  }
}

// ---------------------------------------------------------------------------
// Test cases
// ---------------------------------------------------------------------------

const CASES = [];

function tc(id, name, category, fn) {
  CASES.push({ id, name, category, fn });
}

// ── eval init ───────────────────────────────────────────────────────────────

tc('TC-01', 'eval init — happy path creates evals.json', 'eval init', () => {
  const dir = makeTempDir('init_ok');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  const result = run(['eval', 'init', dir]);
  const created = existsSync(join(dir, 'evals.json'));
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval init <skill-dir>/`,
    result,
    pass: result.exit === 0 && created
        && result.stdout.includes('evals.json')
        && result.stdout.includes('queries scaffolded'),
  };
});

tc('TC-02', 'eval init — evals.json already exists exits 2', 'eval init', () => {
  const dir = makeTempDir('init_exists');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', '{}');
  const result = run(['eval', 'init', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval init <skill-dir>/   # evals.json pre-exists`,
    result,
    pass: result.exit === 2 && result.stderr.includes('already exists'),
  };
});

tc('TC-03', 'eval init — no SKILL.md exits 2', 'eval init', () => {
  const dir = makeTempDir('init_no_skill');
  const result = run(['eval', 'init', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval init <empty-dir>/`,
    result,
    pass: result.exit === 2 && result.stderr.includes('no skill manifest'),
  };
});

tc('TC-04', 'eval init — no path argument exits 2', 'eval init', () => {
  const result = run(['eval', 'init']);
  return {
    command: `skillscore eval init`,
    result,
    pass: result.exit === 2 && result.stderr.includes('skill path'),
  };
});

tc('TC-05', 'eval init — output is valid JSON accepted by EvalParser', 'eval init', () => {
  const dir = makeTempDir('init_json');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  run(['eval', 'init', dir]);
  const validate = run(['eval', 'validate', dir]);
  const evalsJson = existsSync(join(dir, 'evals.json'))
    ? readFileSync(join(dir, 'evals.json'), 'utf8')
    : '';
  rmSync(dir, { recursive: true });
  let parsed = false;
  try { JSON.parse(evalsJson); parsed = true; } catch (_) {}
  return {
    command: `skillscore eval init <skill-dir>/  &&  skillscore eval validate <skill-dir>/`,
    result: validate,
    pass: validate.exit === 0 && parsed,
  };
});

// ── eval validate ───────────────────────────────────────────────────────────

tc('TC-06', 'eval validate — well-formed evals.json exits 0', 'eval validate', () => {
  const dir = makeTempDir('val_ok');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', VALID_EVALS);
  const result = run(['eval', 'validate', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval validate <skill-dir>/`,
    result,
    pass: result.exit === 0
        && result.stdout.includes('OK')
        && result.stdout.includes('queries'),
  };
});

tc('TC-07', 'eval validate — missing evals.json exits 2', 'eval validate', () => {
  const dir = makeTempDir('val_missing');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  const result = run(['eval', 'validate', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval validate <skill-dir>/   # no evals.json`,
    result,
    pass: result.exit === 2,
  };
});

tc('TC-08', 'eval validate — malformed JSON exits 2 with error', 'eval validate', () => {
  const dir = makeTempDir('val_bad_json');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', MALFORMED_EVALS);
  const result = run(['eval', 'validate', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval validate <skill-dir>/   # malformed JSON`,
    result,
    pass: result.exit === 2 && result.stderr.includes('error'),
  };
});

tc('TC-09', 'eval validate — trigger-only queries exits 2', 'eval validate', () => {
  const dir = makeTempDir('val_trigger_only');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', TRIGGER_ONLY_EVALS);
  const result = run(['eval', 'validate', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval validate <skill-dir>/   # no non-trigger queries`,
    result,
    pass: result.exit === 2
        && result.stderr.includes('non-trigger'),
  };
});

tc('TC-10', 'eval validate — small suite (2 queries) warns but exits 0', 'eval validate', () => {
  const dir = makeTempDir('val_small');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', MINIMAL_EVALS);
  const result = run(['eval', 'validate', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval validate <skill-dir>/   # only 2 queries`,
    result,
    pass: result.exit === 0
        && result.stderr.includes('warning'),
  };
});

tc('TC-11', 'eval validate — no path argument exits 2', 'eval validate', () => {
  const result = run(['eval', 'validate']);
  return {
    command: `skillscore eval validate`,
    result,
    pass: result.exit === 2,
  };
});

// ── eval run ────────────────────────────────────────────────────────────────

tc('TC-12', 'eval run — all queries pass for a well-described skill', 'eval run', () => {
  const dir = makeTempDir('run_pass');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', VALID_EVALS);
  const result = run(['eval', 'run', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval run <skill-dir>/`,
    result,
    pass: result.exit === 0 && result.stdout.includes('passed'),
  };
});

tc('TC-13', 'eval run — missing evals.json exits 2', 'eval run', () => {
  const dir = makeTempDir('run_no_evals');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  const result = run(['eval', 'run', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval run <skill-dir>/   # no evals.json`,
    result,
    pass: result.exit === 2,
  };
});

tc('TC-14', 'eval run — no path argument exits 2', 'eval run', () => {
  const result = run(['eval', 'run']);
  return {
    command: `skillscore eval run`,
    result,
    pass: result.exit === 2 && result.stderr.includes('"eval run" needs'),
  };
});

tc('TC-15', 'eval run — JSON format output is valid JSON', 'eval run', () => {
  const dir = makeTempDir('run_json');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', VALID_EVALS);
  const result = run(['--format', 'json', 'eval', 'run', dir]);
  rmSync(dir, { recursive: true });
  let parsed = null;
  try { parsed = JSON.parse(result.stdout); } catch (_) {}
  const hasKeys = parsed && 'skill' in parsed && 'passed' in parsed && 'queries' in parsed;
  return {
    command: `skillscore --format json eval run <skill-dir>/`,
    result: {
      ...result,
      stdout: parsed
        ? JSON.stringify(parsed, null, 2).split('\n').slice(0, 18).join('\n') + '\n  …'
        : result.stdout,
    },
    pass: result.exit <= 1 && hasKeys,
  };
});

tc('TC-16', 'eval run — meta queries never trigger', 'eval run', () => {
  const metaEvals = JSON.stringify({
    skill: 'pdf-form-filler',
    version: 1,
    queries: [
      { query: 'What is PDF form filling?', should_trigger: false },
      { query: 'Explain how PDF forms work', should_trigger: false },
      { query: 'Write a unit test for PDF form filling', should_trigger: false },
      { query: 'Debug why PDF form filling fails', should_trigger: false },
      { query: 'Summarise the documentation for PDF forms', should_trigger: false },
      { query: 'Fill this PDF form with my JSON data', should_trigger: true },
      { query: 'Complete the form fields in this PDF', should_trigger: true },
    ],
  }, null, 2);
  const dir = makeTempDir('run_meta');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', metaEvals);
  const result = run(['eval', 'run', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval run <skill-dir>/   # meta-query non-trigger suite`,
    result,
    pass: result.exit === 0 && result.stdout.includes('passed'),
  };
});

tc('TC-17', 'eval run — boundary queries correctly excluded', 'eval run', () => {
  const boundaryEvals = JSON.stringify({
    skill: 'pdf-form-filler',
    version: 1,
    queries: [
      { query: 'I have a scanned PDF, can you process it?', should_trigger: false },
      { query: 'Handle this image-only PDF', should_trigger: false },
      { query: 'Fill this PDF form with my data', should_trigger: true },
      { query: 'Complete the form fields in this PDF', should_trigger: true },
    ],
  }, null, 2);
  const dir = makeTempDir('run_boundary');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);
  writeFile(dir, 'evals.json', boundaryEvals);
  const result = run(['eval', 'run', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval run <skill-dir>/   # boundary-clause exclusion`,
    result,
    pass: result.exit === 0 && result.stdout.includes('passed'),
  };
});

tc('TC-18', 'eval run — trigger queries fail when description is unrelated', 'eval run', () => {
  // Skill about telemetry; trigger queries are about PDF forms.
  // Heuristic finds 0 shared terms → trigger queries score 0/3 → FAIL.
  // Non-trigger queries use the meta-pattern → correctly stay 0/3 → PASS.
  const unusualManifest = `---
name: unusual-skill
description: >-
  Orchestrates zephyr-encoded telemetry pipelines. Use when deploying
  distributed tracing beacons. Do not use for standard logging.
version: "1.0"
authors:
  - name: QA Test
---

# Unusual skill
`;
  const mismatchEvals = JSON.stringify({
    skill: 'unusual-skill',
    version: 1,
    queries: [
      { query: 'Fill this PDF form with my data',    should_trigger: true  },
      { query: 'Complete the form fields in this PDF', should_trigger: true },
      { query: 'What is a telemetry pipeline?',       should_trigger: false },
      { query: 'Explain distributed tracing',         should_trigger: false },
    ],
  }, null, 2);
  const dir = makeTempDir('run_mismatch');
  writeFile(dir, 'SKILL.md', unusualManifest);
  writeFile(dir, 'evals.json', mismatchEvals);
  const result = run(['eval', 'run', dir]);
  rmSync(dir, { recursive: true });
  return {
    command: `skillscore eval run <skill-dir>/   # description/query mismatch → trigger failures`,
    result,
    pass: result.exit === 1 && result.stdout.includes('failed'),
  };
});

tc('TC-19', 'eval run — unknown eval subcommand exits 2', 'eval run', () => {
  const result = run(['eval', 'frobnicate']);
  return {
    command: `skillscore eval frobnicate`,
    result,
    pass: result.exit === 2 && result.stderr.includes('unknown eval subcommand'),
  };
});

tc('TC-20', 'eval init → validate → run — full end-to-end workflow', 'end-to-end', () => {
  const dir = makeTempDir('e2e');
  writeFile(dir, 'SKILL.md', EXCELLENT_MANIFEST);

  const init     = run(['eval', 'init',     dir]);
  const validate = run(['eval', 'validate', dir]);
  const runCmd   = run(['eval', 'run',      dir]);

  rmSync(dir, { recursive: true });

  const combined = [
    `$ skillscore eval init <skill-dir>/`,
    init.stdout, init.stderr,
    ``,
    `$ skillscore eval validate <skill-dir>/`,
    validate.stdout, validate.stderr,
    ``,
    `$ skillscore eval run <skill-dir>/`,
    runCmd.stdout.split('\n').slice(-8).join('\n'),
  ].filter(Boolean).join('\n');

  return {
    command: `skillscore eval init  →  eval validate  →  eval run`,
    result: {
      exit: runCmd.exit,
      stdout: combined,
      stderr: '',
    },
    pass: init.exit === 0 && validate.exit === 0 && runCmd.exit === 0,
  };
});

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

async function main() {
  console.log('Running QA suite …\n');

  const results = [];
  for (const tc of CASES) {
    process.stdout.write(`  ${tc.id}  ${tc.name} … `);
    const { command, result, pass } = tc.fn();
    results.push({ ...tc, command, result, pass });
    console.log(pass ? '✓ PASS' : '✗ FAIL');
  }

  console.log('\nRendering screenshots …\n');

  for (const r of results) {
    const html = buildHtml(r);
    const outPath = join(EVD, `${r.id}.png`);
    process.stdout.write(`  ${r.id} → ${outPath} … `);
    await screenshot(html, outPath);
    console.log('done');
  }

  // ── Generate REPORT.md ───────────────────────────────────────────────────
  const pass = results.filter(r => r.pass).length;
  const fail = results.filter(r => !r.pass).length;
  const now = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';

  const rows = results.map(r => {
    const status = r.pass ? '✅ PASS' : '❌ FAIL';
    return `| [${r.id}](evidence/${r.id}.png) | ${r.category} | ${r.name} | ${status} |`;
  }).join('\n');

  const detailSections = results.map(r => {
    const status = r.pass ? '✅ PASS' : '❌ FAIL';
    const exitDesc = r.result.exit === 0 ? '0 — success'
                   : r.result.exit === 1 ? '1 — eval failures'
                   : '2 — usage error';
    return `### ${r.id} — ${r.name}

**Category:** \`${r.category}\`
**Status:** ${status}
**Command:** \`${r.command}\`
**Exit code:** ${exitDesc}

![${r.id} screenshot](evidence/${r.id}.png)

---`;
  }).join('\n\n');

  const report = `# Eval Harness — QA Test Report

**Date:** ${now}
**Binary:** \`skillscore 0.3.0\`
**Scope:** \`eval init\` · \`eval validate\` · \`eval run\`
**Mode:** fully offline, no API key

## Summary

| Result | Count |
|---|---|
| ✅ Passed | ${pass} |
| ❌ Failed | ${fail} |
| **Total** | **${pass + fail}** |

## Test matrix

| ID | Category | Test case | Result |
|---|---|---|---|
${rows}

## Test details

${detailSections}

## Evidence

All screenshots are in [\`evidence/\`](evidence/).
Each PNG captures the command, exit code, stdout, and stderr for that test case.

## Notes

- All eval runs use the **HeuristicEvalClient** — term-overlap scoring, fully offline.
- TC-18 intentionally produces failures to verify the exit-1 path.
- TC-20 covers the full three-command workflow end-to-end.
- Screenshots captured at 2× device pixel ratio for Retina clarity.
`;

  writeFileSync(join(QA_DIR, 'REPORT.md'), report);
  console.log(`\nReport written to docs/qa/REPORT.md`);

  console.log(`\n━━━ Results ━━━`);
  console.log(`  Passed: ${pass} / ${pass + fail}`);
  if (fail > 0) {
    console.log(`  Failed:`);
    results.filter(r => !r.pass).forEach(r => console.log(`    ${r.id}  ${r.name}`));
    process.exit(1);
  }
  console.log(`  All tests passed.`);
}

main().catch(err => { console.error(err); process.exit(1); });
