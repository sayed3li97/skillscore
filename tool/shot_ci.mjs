#!/usr/bin/env node
// Render premium evidence cards for the CI/CD article from the REAL GitHub
// Actions run (id 29041629434): the gate summary and the code-scanning alerts.

import { mkdirSync } from 'fs';
import { join, resolve } from 'path';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const REPO = resolve(import.meta.dirname, '..');
const OUT = join(REPO, 'docs', 'assets', 'shots');
mkdirSync(OUT, { recursive: true });

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const CSS = `
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#010204;padding:26px;font-family:ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,monospace;width:920px}
  .card{background:#0d1117;border:1px solid #1e242d;border-radius:12px;overflow:hidden;box-shadow:0 16px 44px rgba(0,0,0,.5)}
  .bar{background:#10151d;border-bottom:1px solid #1b2029;padding:13px 18px;display:flex;align-items:center;gap:12px}
  .glyph{color:#4d9fff;font-size:14px}
  .ttl{color:#e6edf3;font-size:14px;font-weight:600}
  .sub{color:#6b7684;font-size:13px}
  .spacer{flex:1}
  .ok{color:#3fb950;border:1px solid #24603a;background:#0d2119;border-radius:20px;padding:3px 12px;font-size:12px;font-weight:600}
  .count{color:#e3b341;border:1px solid #5c4a1f;background:#211c0d;border-radius:20px;padding:3px 12px;font-size:12px;font-weight:600}
  .body{padding:18px 20px;font-size:13px;line-height:1.62;color:#e6edf3;white-space:pre-wrap}
  .prompt{color:#3fb950}
  .green{color:#3fb950;font-weight:600}
  .blue{color:#4d9fff}
  .dim{color:#6b7684}
  .bar2{color:#3a7fd5}
  .sep{border:none;border-top:1px solid #1b2029;margin:14px 0}
  .row{display:flex;align-items:center;padding:7px 20px;border-top:1px solid #12171f}
  .rid{color:#79c0ff;width:290px}
  .rloc{color:#8b949e;flex:1;font-size:12px}
  .rn{color:#e3b341}
  .sevdot{width:8px;height:8px;border-radius:50%;background:#e3b341;margin-right:10px}
`;

async function render(name, inner, width = 972) {
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>${CSS}</style></head><body>${inner}</body></html>`;
  const b = await puppeteer.launch({ executablePath: CHROME, args: ['--no-sandbox', '--disable-setuid-sandbox'], headless: true });
  const p = await b.newPage();
  await p.setViewport({ width, height: 400, deviceScaleFactor: 2 });
  await p.setContent(html, { waitUntil: 'networkidle0' });
  const h = await p.evaluate(() => document.body.scrollHeight);
  await p.setViewport({ width, height: h, deviceScaleFactor: 2 });
  await p.setContent(html, { waitUntil: 'networkidle0' });
  await p.screenshot({ path: join(OUT, `${name}.png`) });
  await b.close();
  console.log(`  ${name}.png`);
}

// ---- Card 1: the GitHub Actions run summary (real output) ----
const bars = (label, pts) =>
  `  ${label.padEnd(38)}${pts.padStart(7)}  <span class="bar2">██████████</span>`;
const runBody =
`<div class="cmdline"><span class="prompt">$</span> skillscore test/fixtures/excellent --min-score 90 --no-color</div>
<span class="dim">pdf-form-filler  (test/fixtures/excellent/pdf-form-filler/SKILL.md)</span>
  <span class="green">Score: 100/100  Grade: A</span>

${bars('A  Frontmatter validity', '17/17')}
${bars('B  Description quality', '28/28')}
${bars('C  Conciseness & token economy', '15/15')}
${bars('D  Structure & progressive disclosure', '15/15')}
${bars('E  Instruction quality', '20/20')}
${bars('F  Content hygiene', '10/10')}
  <span class="dim">G  Safety &amp; scripts                    no penalty</span>

  <span class="green">No findings. Nice work.</span>
<hr class="sep">
<span class="blue">SARIF uploaded  &#8594;  30 findings now in the Security tab</span>
<span class="dim">gate passed &#183; exit 0 &#183; job success in 31s</span>`;

const card1 = `<div class="card">
  <div class="bar">
    <span class="glyph">&#9654;</span><span class="ttl">GitHub Actions</span>
    <span class="sub">skill lint (demo)</span><span class="spacer"></span>
    <span class="ok">&#10003; success &#183; 31s</span>
  </div>
  <div class="body">${runBody}</div>
</div>`;

// ---- Card 2: code scanning alerts (real, grouped) ----
const alerts = [
  ['E3_feedback_loop', 3], ['E1_anti_patterns', 3], ['C3_excessive_optionality', 3],
  ['C2_explainer_bloat', 3], ['E4_code_example', 2], ['E2_workflow_checklist', 2],
  ['A4_description_present', 2], ['A2_name_format', 2], ['A1_frontmatter_present', 2],
  ['G1_safety_section', 1], ['F3_consistent_terminology', 1], ['F2_forward_slashes', 1],
];
const rows = alerts.map(([id, n]) =>
  `<div class="row"><span class="sevdot"></span><span class="rid">${esc(id)}</span>`
  + `<span class="rloc">test/fixtures/&hellip;/SKILL.md</span><span class="rn">${n}&times;</span></div>`
).join('');
const card2 = `<div class="card">
  <div class="bar">
    <span class="glyph">&#9673;</span><span class="ttl">Security</span>
    <span class="sub">Code scanning &#183; skillscore</span><span class="spacer"></span>
    <span class="count">30 open</span>
  </div>
  <div class="body" style="padding:6px 0 10px 0">${rows}
    <div class="row" style="border-top:1px solid #1b2029"><span style="width:18px"></span><span class="dim">&hellip; 6 more rules &#183; 30 findings total, one per rubric violation</span></div>
  </div>
</div>`;

console.log('Rendering CI evidence cards …');
await render('ci-github', card1);
await render('ci-codescanning', card2);
console.log('done');
