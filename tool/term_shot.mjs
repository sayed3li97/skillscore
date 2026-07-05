#!/usr/bin/env node
// Render premium "terminal window" screenshots of skillscore commands, in the
// dark / monospace / blue-accent house style. Runs the compiled binary, wraps
// the real output in a macOS-style window, and screenshots to PNG.
//
// Usage: dart compile exe bin/skillscore.dart -o /tmp/sk && node tool/term_shot.mjs

import { spawnSync } from 'child_process';
import { mkdirSync } from 'fs';
import { join, resolve } from 'path';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BIN    = '/tmp/sk';
const REPO   = resolve(import.meta.dirname, '..');
const OUT    = join(REPO, 'docs', 'assets', 'shots');
mkdirSync(OUT, { recursive: true });

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function run(args, cwd) {
  const r = spawnSync(BIN, args, {
    cwd, encoding: 'utf8', timeout: 30000,
    env: { ...process.env, NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  return ((r.stdout ?? '') + (r.stderr ?? '')).replace(/\n+$/, '');
}

function highlight(text) {
  return esc(text).split('\n').map((line) => {
    if (/Did you mean/.test(line))
      return line.replace(/(Did you mean[^?]*\?)/, '<b style="color:#f0b72f">$1</b>')
                 .replace(/^(.*)$/, '<span style="color:#e3b341">$1</span>');
    if (/\bERROR\b/.test(line))   return `<span style="color:#f85149">${line}</span>`;
    if (/\bWARNING\b/.test(line)) return `<span style="color:#e3b341">${line}</span>`;
    if (/\bINFO\b/.test(line))    return `<span style="color:#79c0ff">${line}</span>`;
    if (/No findings/.test(line)) return `<span style="color:#3fb950">${line}</span>`;
    if (/Grade:\s*A\b/.test(line)) return line.replace(/(Score:.*Grade:\s*A\b)/, '<span style="color:#3fb950;font-weight:600">$1</span>');
    if (/Grade:\s*C\b/.test(line)) return line.replace(/(Score:.*Grade:\s*C\b)/, '<span style="color:#e3b341;font-weight:600">$1</span>');
    if (/Grade:\s*[DF]\b/.test(line)) return line.replace(/(Score:.*Grade:\s*[DF]\b)/, '<span style="color:#f85149;font-weight:600">$1</span>');
    if (/Score:/.test(line))      return `<span style="color:#f0f6fc;font-weight:600">${line}</span>`;
    if (/^\s+[A-G]\s{2}\S/.test(line))
      return line.replace(/(█+)/g, '<span style="color:#3a7fd5">$1</span>')
                 .replace(/(░+)/g, '<span style="color:#232a33">$1</span>')
                 .replace(/^(\s+[A-G]\s{2}[A-Za-z0-9 &.,;()\/-]+?)(\s{2,}|$)/, '<span style="color:#8b949e">$1</span>$2');
    if (/\bpassed\b/.test(line) && /\bavg\b|\blowest\b|skills?/.test(line))
      return `<span style="color:#cfe4ff">${line}</span>`;
    if (/^\s*(Tokens|description \(permanent\)|full manifest \(active\))/.test(line))
      return `<span style="color:#6b7684">${line}</span>`;
    if (/PASS/.test(line)) return line.replace(/PASS/g, '<span style="color:#3fb950">PASS</span>');
    if (/FAIL/.test(line)) return line.replace(/FAIL/g, '<span style="color:#f85149">FAIL</span>');
    if (/^\s+(fix|source|Why|Fix|Category|Points|Severity|Targets|Title):/.test(line))
      return `<span style="color:#6b7684">${line}</span>`;
    if (/^[A-G]\d_[a-z_]+/.test(line)) return `<span style="color:#79c0ff">${line}</span>`;
    return line;
  }).join('\n');
}

function windowHtml(title, body) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#010204;padding:26px;font-family:ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,'DejaVu Sans Mono',monospace}
    .win{background:#0d1117;border:1px solid #1e242d;border-radius:12px;overflow:hidden;width:940px;
         box-shadow:0 20px 60px rgba(0,0,0,.5)}
    .bar{height:42px;background:#10151d;border-bottom:1px solid #1b2029;display:flex;align-items:center;padding:0 16px;position:relative}
    .dot{width:12px;height:12px;border-radius:50%;margin-right:8px}
    .r{background:#ff5f57}.y{background:#febc2e}.gg{background:#28c840}
    .title{position:absolute;left:0;right:0;text-align:center;color:#6b7684;font-size:13px;pointer-events:none}
    .body{padding:20px 22px;white-space:pre-wrap;word-break:break-word;color:#e6edf3;font-size:13px;line-height:1.62}
    .prompt{color:#3fb950}
    .cmd{color:#e6edf3}
    .cmdline{margin-bottom:14px}
  </style></head><body>
    <div class="win">
      <div class="bar">
        <span class="dot r"></span><span class="dot y"></span><span class="dot gg"></span>
        <span class="title">${esc(title)}</span>
      </div>
      <div class="body">${body}</div>
    </div>
  </body></html>`;
}

async function shot(name, title, cmdline, output) {
  const body =
    `<div class="cmdline"><span class="prompt">$</span> <span class="cmd">${esc(cmdline)}</span></div>` +
    highlight(output);
  const html = windowHtml(title, body);
  const browser = await puppeteer.launch({
    executablePath: CHROME, args: ['--no-sandbox', '--disable-setuid-sandbox'], headless: true,
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 992, height: 400, deviceScaleFactor: 2 });
  await page.setContent(html, { waitUntil: 'networkidle0' });
  const box = await (await page.$('.win')).boundingBox();
  await page.setViewport({ width: 992, height: Math.ceil(box.height) + 52, deviceScaleFactor: 2 });
  await page.setContent(html, { waitUntil: 'networkidle0' });
  await (await page.$('.win')).screenshot({ path: join(OUT, `${name}.png`) });
  await browser.close();
  console.log(`  ${name}.png`);
}

const EX = 'test/fixtures/excellent/pdf-form-filler';

// Keep only skill headers, score lines, and the summary — a compact
// multi-skill comparison instead of every finding.
function trimMultipath(out) {
  const keep = [];
  for (const l of out.split('\n')) {
    if (/\(.*SKILL\.md\)\s*$/.test(l)) keep.push(l);
    else if (/^\s*Score:/.test(l)) keep.push(l, '');
    else if (/^Summary\b/.test(l)) keep.push(l);
    else if (/skills scored/.test(l)) keep.push(l);
  }
  return keep.join('\n').replace(/\n+$/, '');
}

// Drop the live progress; show the report header, a few result rows, and
// the pass/fail summary.
function trimEval(out) {
  const lines = out.split('\n');
  const idx = lines.findIndex((l) => /^eval\s/.test(l));
  const rep = idx >= 0 ? lines.slice(idx) : lines;
  const keep = [];
  let rows = 0;
  for (const l of rep) {
    if (/^\s*(PASS|FAIL)\s+\S/.test(l)) {
      rows++;
      if (rows <= 6) keep.push(l);
      else if (rows === 7) keep.push('        …  (14 more queries)');
    } else {
      keep.push(l);
    }
  }
  return keep.join('\n').replace(/\n{3,}/g, '\n\n').replace(/\n+$/, '');
}

console.log('Rendering terminal shots …');

// 1. Hero: score a strong skill (clean display path)
spawnSync('cp', ['-r', join(REPO, EX), '/tmp/skdemo/my-skill'], { encoding: 'utf8' });
await shot('score', 'skillscore my-skill/', 'skillscore my-skill/',
  run(['my-skill/', '--no-color'], '/tmp/skdemo'));

// 2. Multi-path with summary (compact)
await shot('multipath', 'skillscore skills/', 'skillscore skills/',
  trimMultipath(run(['skills/', '--no-color'], '/tmp/skdemo')));

// 3. Eval run (compact)
await shot('eval', 'skillscore eval run my-skill/', 'skillscore eval run my-skill/',
  (() => {
    const dir = '/tmp/skdemo/skills/pdf-form-filler';
    run(['eval', 'init', dir]);
    return trimEval(run(['eval', 'run', dir, '--no-color']));
  })());

// 4. explain a rule
await shot('explain', 'skillscore explain B2_description_when', 'skillscore explain B2_description_when',
  run(['explain', 'B2_description_when', '--no-color'], REPO));

console.log('done');
