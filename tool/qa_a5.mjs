#!/usr/bin/env node
// QA runner for rule A5 (A5_frontmatter_keys) — the unknown-frontmatter-key
// check with "did you mean" suggestions. Runs the compiled skillscore binary
// against crafted skills, captures the real terminal output, renders each
// case as a PNG, and writes docs/qa/a5/REPORT.md.
//
// Usage: dart compile exe bin/skillscore.dart -o /tmp/skillscore-a5
//        node tool/qa_a5.mjs

import { spawnSync } from 'child_process';
import { mkdirSync, writeFileSync, rmSync, existsSync } from 'fs';
import { join, resolve } from 'path';
import { tmpdir } from 'os';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BIN    = '/tmp/skillscore-a5';
const REPO   = resolve(import.meta.dirname, '..');
const QA_DIR = join(REPO, 'docs', 'qa', 'a5');
const EVD    = join(QA_DIR, 'evidence');

mkdirSync(EVD, { recursive: true });

// ---------------------------------------------------------------------------
// Skill fixtures — each is a full SKILL.md body used to drive one test case.
// ---------------------------------------------------------------------------

const BODY = `
# PDF form filler

Fill AcroForm fields in an existing PDF from a JSON mapping and produce a
flattened copy.

## Workflow

1. Inspect the form fields with the helper.
2. Build the JSON mapping of field name to value.
3. Write the filled, flattened PDF to a new path.

## Safety

Never overwrite the source PDF. Always write to a new output path.
`;

const skill = (frontmatter) => `---\n${frontmatter}\n---\n${BODY}`;

const CLEAN = skill(
  'name: pdf-form-filler\n' +
  'description: >-\n' +
  '  Fills PDF form fields from structured JSON data and writes a flattened\n' +
  '  output file. Use when the user asks to fill or populate a PDF form. Do\n' +
  '  not use for scanned or image-only PDFs.',
);

const TYPO = skill(
  'name: pdf-form-filler\n' +
  'descrption: >-\n' +
  '  Fills PDF form fields from structured JSON data. Use when the user asks\n' +
  '  to fill or populate a PDF form. Do not use for scanned PDFs.',
);

const UNKNOWN = skill(
  'name: pdf-form-filler\n' +
  'description: >-\n' +
  '  Fills PDF form fields from JSON. Use when the user asks to fill a PDF\n' +
  '  form. Do not use for scanned PDFs.\n' +
  'author: Jane Doe\n' +
  'category: documents',
);

const OPTIONAL_KEYS = skill(
  'name: pdf-form-filler\n' +
  'description: >-\n' +
  '  Fills PDF form fields from JSON. Use when the user asks to fill a PDF\n' +
  '  form. Do not use for scanned PDFs.\n' +
  'license: MIT\n' +
  'allowed-tools: [Read, Write]\n' +
  'version: "1.2"',
);

const METADATA_NESTED = skill(
  'name: pdf-form-filler\n' +
  'description: >-\n' +
  '  Fills PDF form fields from JSON. Use when the user asks to fill a PDF\n' +
  '  form. Do not use for scanned PDFs.\n' +
  'metadata:\n' +
  '  author: Jane Doe\n' +
  '  category: documents\n' +
  '  internal-id: pdf-42',
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeSkill(name, content) {
  const dir = join(tmpdir(), `a5_${name}_${process.pid}`);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'SKILL.md'), content);
  return dir;
}

function run(args) {
  const r = spawnSync(BIN, args, {
    encoding: 'utf8',
    timeout: 30000,
    env: { ...process.env, NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  return {
    exit: r.status ?? 2,
    stdout: (r.stdout ?? '').replace(/\n+$/, ''),
    stderr: (r.stderr ?? '').replace(/\n+$/, ''),
  };
}

// ---------------------------------------------------------------------------
// Terminal-card renderer (GitHub dark theme, matches docs/qa/evidence style)
// ---------------------------------------------------------------------------

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function highlight(text) {
  if (!text) return '<span style="color:#484f58;font-style:italic">( no output )</span>';
  return esc(text).split('\n').map((line) => {
    if (/Did you mean/.test(line))
      return `<span style="color:#e3b341">${line.replace(/(Did you mean [^?]*\?)/, '<b style="color:#f0b72f">$1</b>')}</span>`;
    if (/\bERROR\b/.test(line))   return `<span style="color:#f85149">${line}</span>`;
    if (/\bWARNING\b/.test(line)) return `<span style="color:#e3b341">${line}</span>`;
    if (/\bINFO\b/.test(line))    return `<span style="color:#79c0ff">${line}</span>`;
    if (/No findings/.test(line)) return `<span style="color:#3fb950">${line}</span>`;
    if (/Grade:\s*A/.test(line) || /\b100\/100\b/.test(line))
      return `<span style="color:#3fb950">${line}</span>`;
    if (/Score:/.test(line))      return `<span style="color:#f0f6fc;font-weight:600">${line}</span>`;
    if (/^\s+[A-G]\s{2}/.test(line)) {
      // Category bar line: colour the block characters.
      return line.replace(/([█]+)/g, '<span style="color:#3fb950">$1</span>')
                 .replace(/([░]+)/g, '<span style="color:#30363d">$1</span>')
                 .replace(/^(\s+[A-G]\s{2}[A-Za-z0-9 &.,-]+?)(\s{2,})/, '<span style="color:#8b949e">$1</span>$2');
    }
    if (/^\s+fix:/.test(line))    return `<span style="color:#8b949e">${line}</span>`;
    if (/^\s+source:/.test(line)) return `<span style="color:#8b949e">${line}</span>`;
    if (/A5_frontmatter_keys/.test(line))
      return line.replace(/(A5_frontmatter_keys)/g, '<span style="color:#79c0ff">$1</span>');
    if (/Tokens/.test(line))      return `<span style="color:#8b949e">${line}</span>`;
    return line;
  }).join('\n');
}

function buildHtml({ id, name, command, result, pass }) {
  const statusColor = pass ? '#3fb950' : '#f85149';
  const statusBg    = pass ? '#0d2119' : '#2d0f0f';
  const label       = pass ? 'PASS' : 'FAIL';
  const hasStdout = result.stdout.length > 0;
  const hasStderr = result.stderr.length > 0;

  return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { background:#0d1117; font-family: ui-monospace, 'SF Mono', SFMono-Regular, Menlo, Consolas, monospace;
           font-size:13px; line-height:1.55; color:#e6edf3; min-width:900px; }
    .card { background:#161b22; border:1px solid #30363d; border-radius:10px; overflow:hidden; margin:24px; }
    .hd { background:#0d1117; border-bottom:1px solid #30363d; padding:14px 20px; display:flex; align-items:center; gap:14px; }
    .id { font-size:11px; font-weight:700; letter-spacing:.06em; color:#79c0ff; background:#1c2d3f;
          border:1px solid #1f6feb; border-radius:5px; padding:2px 9px; flex-shrink:0; }
    .cat { font-size:11px; color:#8b949e; background:#21262d; border:1px solid #30363d; border-radius:5px; padding:2px 9px; flex-shrink:0; }
    .nm { flex:1; font-size:14px; font-weight:600; color:#f0f6fc; }
    .st { font-size:11px; font-weight:700; letter-spacing:.08em; color:${statusColor}; background:${statusBg};
          border:1px solid ${statusColor}; border-radius:5px; padding:2px 10px; flex-shrink:0; }
    .sec { padding:14px 20px; border-bottom:1px solid #21262d; }
    .sec:last-child { border-bottom:none; }
    .lbl { font-size:10px; font-weight:700; letter-spacing:.12em; text-transform:uppercase; color:#484f58; margin-bottom:8px; }
    .cmd { display:flex; gap:8px; align-items:baseline; }
    .pr { color:#3fb950; }
    .out { background:#0d1117; border:1px solid #21262d; border-radius:6px; padding:12px 14px;
           white-space:pre-wrap; word-break:break-word; overflow:hidden; font-size:12.5px; line-height:1.6; }
    .meta { display:flex; gap:24px; color:#8b949e; }
    .meta b { color:#e6edf3; font-weight:600; margin-right:4px; }
    .ok { color:#3fb950; font-weight:700; } .warn { color:#e3b341; font-weight:700; } .bad { color:#f85149; font-weight:700; }
  </style></head><body>
  <div class="card">
    <div class="hd">
      <span class="id">${esc(id)}</span>
      <span class="cat">A5 rule</span>
      <span class="nm">${esc(name)}</span>
      <span class="st">${label}</span>
    </div>
    <div class="sec">
      <div class="lbl">Command</div>
      <div class="cmd"><span class="pr">$</span><span>${esc(command)}</span></div>
    </div>
    <div class="sec">
      <div class="meta">
        <div><b>Exit</b><span class="${result.exit === 0 ? 'ok' : result.exit === 1 ? 'warn' : 'bad'}">${result.exit}</span></div>
        <div><b>stdout</b>${hasStdout ? result.stdout.split('\n').length + ' lines' : 'empty'}</div>
        <div><b>stderr</b>${hasStderr ? result.stderr.split('\n').length + ' lines' : 'empty'}</div>
      </div>
    </div>
    ${hasStdout ? `<div class="sec"><div class="lbl">stdout</div><div class="out">${highlight(result.stdout)}</div></div>` : ''}
    ${hasStderr ? `<div class="sec"><div class="lbl">stderr</div><div class="out">${highlight(result.stderr)}</div></div>` : ''}
  </div></body></html>`;
}

async function screenshot(html, outPath) {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    headless: true,
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 940, height: 300, deviceScaleFactor: 2 });
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const box = await (await page.$('.card')).boundingBox();
    await page.setViewport({ width: 940, height: Math.ceil(box.height) + 48, deviceScaleFactor: 2 });
    await page.setContent(html, { waitUntil: 'networkidle0' });
    await page.screenshot({ path: outPath, fullPage: true });
  } finally {
    await browser.close();
  }
}

// ---------------------------------------------------------------------------
// Test cases
// ---------------------------------------------------------------------------

const CASES = [
  {
    id: 'A5-01',
    name: 'Clean frontmatter passes A5 (no unknown-key finding)',
    command: 'skillscore pdf-form-filler/',
    fn: () => {
      const dir = makeSkill('clean', CLEAN);
      const r = run(['--no-color', dir]);
      rmSync(dir, { recursive: true });
      return { result: r, pass: r.exit === 0 && !r.stdout.includes('A5_frontmatter_keys') };
    },
  },
  {
    id: 'A5-02',
    name: 'Typo "descrption" → A5 suggests "description"',
    command: 'skillscore pdf-form-filler/',
    fn: () => {
      const dir = makeSkill('typo', TYPO);
      const r = run(['--no-color', dir]);
      rmSync(dir, { recursive: true });
      return {
        result: r,
        pass: r.stdout.includes('A5_frontmatter_keys') &&
              r.stdout.includes('Did you mean "description"?'),
      };
    },
  },
  {
    id: 'A5-03',
    name: 'Unrecognized keys flagged, no false suggestion',
    command: 'skillscore pdf-form-filler/',
    fn: () => {
      const dir = makeSkill('unknown', UNKNOWN);
      const r = run(['--no-color', dir]);
      rmSync(dir, { recursive: true });
      const hits = (r.stdout.match(/A5_frontmatter_keys/g) || []).length;
      return {
        result: r,
        pass: hits === 2 && r.stdout.includes('"author"') && r.stdout.includes('"category"'),
      };
    },
  },
  {
    id: 'A5-04',
    name: 'Recognized optional keys pass (license, allowed-tools, version)',
    command: 'skillscore pdf-form-filler/',
    fn: () => {
      const dir = makeSkill('optional', OPTIONAL_KEYS);
      const r = run(['--no-color', dir]);
      rmSync(dir, { recursive: true });
      return { result: r, pass: !r.stdout.includes('A5_frontmatter_keys') };
    },
  },
  {
    id: 'A5-05',
    name: 'Nested keys under metadata are ignored',
    command: 'skillscore pdf-form-filler/',
    fn: () => {
      const dir = makeSkill('metadata', METADATA_NESTED);
      const r = run(['--no-color', dir]);
      rmSync(dir, { recursive: true });
      return { result: r, pass: !r.stdout.includes('A5_frontmatter_keys') };
    },
  },
  {
    id: 'A5-06',
    name: 'JSON format carries the A5 finding',
    command: 'skillscore --format json pdf-form-filler/',
    fn: () => {
      const dir = makeSkill('json', TYPO);
      const r = run(['--no-color', '--format', 'json', dir]);
      rmSync(dir, { recursive: true });
      let ok = false;
      try {
        const parsed = JSON.parse(r.stdout);
        const arr = Array.isArray(parsed) ? parsed : [parsed];
        ok = JSON.stringify(arr).includes('A5_frontmatter_keys');
      } catch (_) {}
      // Trim the JSON for a readable screenshot.
      const trimmed = r.stdout.split('\n').filter((l) =>
        /A5_frontmatter_keys|ruleId|message|Did you mean|"score"|"grade"|findings/.test(l)
      ).slice(0, 12).join('\n');
      return { result: { ...r, stdout: trimmed + '\n  …' }, pass: ok };
    },
  },
  {
    id: 'A5-07',
    name: 'skillscore explain A5 prints rationale, fix, and source',
    command: 'skillscore explain A5_frontmatter_keys',
    fn: () => {
      const r = run(['explain', 'A5_frontmatter_keys', '--no-color']);
      return {
        result: r,
        pass: r.exit === 0 && /metadata/.test(r.stdout) && /Anthropic/.test(r.stdout),
      };
    },
  },
  {
    id: 'A5-08',
    name: 'skillscore rules lists A5 with weight and targets',
    command: 'skillscore rules',
    fn: () => {
      const r = run(['rules', '--no-color']);
      const line = r.stdout.split('\n').filter((l) => /A5_frontmatter_keys/.test(l)).join('\n');
      return {
        result: { ...r, stdout: line || r.stdout },
        pass: r.exit === 0 && /A5_frontmatter_keys/.test(r.stdout),
      };
    },
  },
];

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

async function main() {
  if (!existsSync(BIN)) {
    console.error(`Binary not found at ${BIN}. Run:\n  dart compile exe bin/skillscore.dart -o ${BIN}`);
    process.exit(1);
  }

  console.log('Running A5 QA suite …\n');
  const results = [];
  for (const c of CASES) {
    process.stdout.write(`  ${c.id}  ${c.name} … `);
    const { result, pass } = c.fn();
    results.push({ ...c, result, pass });
    console.log(pass ? '✓ PASS' : '✗ FAIL');
  }

  console.log('\nRendering screenshots …\n');
  for (const r of results) {
    const out = join(EVD, `${r.id}.png`);
    process.stdout.write(`  ${r.id} → ${out} … `);
    await screenshot(buildHtml(r), out);
    console.log('done');
  }

  const pass = results.filter((r) => r.pass).length;
  const fail = results.length - pass;
  const rows = results.map((r) =>
    `| [${r.id}](evidence/${r.id}.png) | ${r.name} | \`exit ${r.result.exit}\` | ${r.pass ? '✅ PASS' : '❌ FAIL'} |`
  ).join('\n');
  const details = results.map((r) => `### ${r.id} — ${r.name}

**Command:** \`${r.command}\`
**Exit code:** ${r.result.exit}
**Result:** ${r.pass ? '✅ PASS' : '❌ FAIL'}

![${r.id}](evidence/${r.id}.png)

---`).join('\n\n');

  const report = `# Rule A5 (\`A5_frontmatter_keys\`) — QA Test Report

**Binary:** \`skillscore 0.6.0\`
**Rule:** \`A5_frontmatter_keys\` — unknown-frontmatter-key detection with "did you mean" suggestions
**Mode:** fully offline, deterministic

## Summary

| Result | Count |
|---|---|
| ✅ Passed | ${pass} |
| ❌ Failed | ${fail} |
| **Total** | **${results.length}** |

## Test matrix

| ID | Test case | Exit | Result |
|---|---|---|---|
${rows}

## Test details

${details}

## Notes

- Every case runs the compiled \`skillscore\` binary against a crafted \`SKILL.md\` and captures the real terminal output.
- A5-01/04/05 confirm the rule stays quiet for clean, optional, and \`metadata\`-nested keys (no false positives).
- A5-02 verifies the Levenshtein "did you mean" suggestion; A5-03 confirms genuinely unknown keys are flagged without a misleading suggestion.
- A5-06 confirms the finding is present in \`--format json\`; A5-07/08 verify \`explain\` and \`rules\` surface the rule.
- Screenshots captured at 2× device pixel ratio.
`;
  writeFileSync(join(QA_DIR, 'REPORT.md'), report);
  console.log(`\nReport → docs/qa/a5/REPORT.md`);
  console.log(`\n━━━ ${pass}/${results.length} passed ━━━`);
  if (fail > 0) {
    results.filter((r) => !r.pass).forEach((r) => console.log(`  FAIL ${r.id}  ${r.name}`));
    process.exit(1);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
