#!/usr/bin/env node
// Premium before/after screenshot for `skillscore --fix`: a misspelled
// `descrption:` key drops a skill to 68/D; --fix renames it and the skill
// recovers to 100/A. Two stacked terminal windows in the house style.

import { spawnSync } from 'child_process';
import { mkdirSync, writeFileSync, rmSync } from 'fs';
import { join, resolve } from 'path';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BIN = '/tmp/sk';
const REPO = resolve(import.meta.dirname, '..');
const OUT = join(REPO, 'docs', 'assets', 'shots', 'fix.png');

const DEMO = '/tmp/fixdemo';
rmSync(DEMO, { recursive: true, force: true });
mkdirSync(join(DEMO, 'my-skill'), { recursive: true });
writeFileSync(join(DEMO, 'my-skill', 'SKILL.md'), `---
name: pdf-form-filler
descrption: >-
  Fills PDF form fields from structured JSON data and writes a flattened
  output file. Use when the user asks to fill or populate a PDF form. Do
  not use for scanned or image-only PDFs.
---

# PDF form filler

Fill AcroForm fields in an existing PDF from a JSON mapping.

## Workflow

1. Inspect the fields. Run the helper, then build the JSON, then fill.
2. Validate the output; if a field is missing, fix the mapping and re-run.

\`\`\`bash
python scripts/fill.py input.pdf mapping.json out.pdf
\`\`\`

## Safety

Never overwrite the source PDF. Always write to a new output path.
`);

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function run(args) {
  const r = spawnSync(BIN, args, {
    cwd: DEMO, encoding: 'utf8',
    env: { ...process.env, NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  return ((r.stdout ?? '') + (r.stderr ?? '')).replace(/\n+$/, '');
}

// BEFORE: header, score, the A4 error and A5 [fixable] warning (message only).
function trimBefore(out) {
  const lines = out.split('\n');
  const keep = [];
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (/SKILL\.md\)\s*$/.test(l)) keep.push(l);
    else if (/^\s*Score:/.test(l)) keep.push(l, '');
    else if (/^\s*(ERROR|WARNING)\s+A[45]_/.test(l)) keep.push(l, lines[i + 1]);
  }
  return keep.join('\n');
}

// AFTER: the Fixed summary, the score, and the clean result.
function trimAfter(out) {
  const lines = out.split('\n');
  const keep = [];
  for (const l of lines) {
    if (/^Fixed /.test(l)) keep.push(l);
    else if (/rename ".*" to ".*"/.test(l)) keep.push(l, '');
    else if (/SKILL\.md\)\s*$/.test(l)) keep.push(l);
    else if (/^\s*Score:/.test(l)) keep.push(l);
    else if (/No findings/.test(l)) keep.push('', l);
  }
  return keep.join('\n');
}

function highlight(text) {
  return esc(text).split('\n').map((line) => {
    if (/\[fixable\]/.test(line))
      return line.replace(/\[fixable\]/, '<span style="color:#3fb950">[fixable]</span>')
                 .replace(/\bWARNING\b/, '<span style="color:#e3b341">WARNING</span>')
                 .replace(/(A5_frontmatter_keys)/, '<span style="color:#79c0ff">$1</span>');
    if (/^Fixed /.test(line)) return `<span style="color:#3fb950;font-weight:700">${line}</span>`;
    if (/rename ".*" to ".*"/.test(line))
      return line.replace(/(rename ".*?" to ".*?")/, '<b style="color:#cfe4ff">$1</b>')
                 .replace(/^(\s*\S+)/, '<span style="color:#8b949e">$1</span>');
    if (/\bERROR\b/.test(line))
      return line.replace(/\bERROR\b/, '<span style="color:#f85149">ERROR</span>')
                 .replace(/(A4_description_present)/, '<span style="color:#79c0ff">$1</span>');
    if (/Grade:\s*A\b/.test(line)) return line.replace(/(Score:.*Grade:\s*A)/, '<span style="color:#3fb950;font-weight:600">$1</span>');
    if (/Grade:\s*[DF]\b/.test(line)) return line.replace(/(Score:.*Grade:\s*[DF])/, '<span style="color:#f85149;font-weight:600">$1</span>');
    if (/No findings/.test(line)) return `<span style="color:#3fb950">${line}</span>`;
    if (/SKILL\.md\)\s*$/.test(line)) return `<span style="color:#f0f6fc;font-weight:600">${line.replace(/(\(.*\))/, '<span style="color:#6b7684;font-weight:400">$1</span>')}</span>`;
    return line;
  }).join('\n');
}

function windowHtml(title, cmd, bodyText) {
  const body =
    `<div class="cmdline"><span class="prompt">$</span> <span class="cmd">${esc(cmd)}</span></div>` +
    highlight(bodyText);
  return `<div class="win">
    <div class="bar"><span class="dot r"></span><span class="dot y"></span><span class="dot gg"></span>
      <span class="title">${esc(title)}</span></div>
    <div class="body">${body}</div>
  </div>`;
}

const before = trimBefore(run(['my-skill/', '--no-color']));
const after = trimAfter(run(['my-skill/', '--fix', '--no-color']));

const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#010204;padding:26px;font-family:ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,monospace;width:900px}
  .win{background:#0d1117;border:1px solid #1e242d;border-radius:12px;overflow:hidden;box-shadow:0 16px 44px rgba(0,0,0,.5)}
  .bar{height:40px;background:#10151d;border-bottom:1px solid #1b2029;display:flex;align-items:center;padding:0 15px;position:relative}
  .dot{width:12px;height:12px;border-radius:50%;margin-right:8px}
  .r{background:#ff5f57}.y{background:#febc2e}.gg{background:#28c840}
  .title{position:absolute;left:0;right:0;text-align:center;color:#6b7684;font-size:13px}
  .body{padding:18px 20px;white-space:pre-wrap;word-break:break-word;color:#e6edf3;font-size:13px;line-height:1.6}
  .prompt{color:#3fb950}.cmd{color:#e6edf3}.cmdline{margin-bottom:12px}
  .arrow{color:#4d9fff;font-size:22px;text-align:center;padding:10px 0}
</style></head><body>
  ${windowHtml('skillscore my-skill/', 'skillscore my-skill/', before)}
  <div class="arrow">&#8595;&nbsp; skillscore my-skill/ --fix</div>
  ${windowHtml('skillscore my-skill/ --fix', 'skillscore my-skill/ --fix', after)}
</body></html>`;

const browser = await puppeteer.launch({
  executablePath: CHROME, args: ['--no-sandbox', '--disable-setuid-sandbox'], headless: true,
});
const page = await browser.newPage();
await page.setViewport({ width: 900, height: 400, deviceScaleFactor: 2 });
await page.setContent(html, { waitUntil: 'networkidle0' });
const h = await page.evaluate(() => document.body.scrollHeight);
await page.setViewport({ width: 900, height: h, deviceScaleFactor: 2 });
await page.setContent(html, { waitUntil: 'networkidle0' });
await page.screenshot({ path: OUT });
await browser.close();
console.log(`wrote ${OUT}`);
