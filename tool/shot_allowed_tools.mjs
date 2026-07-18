#!/usr/bin/env node
// Premium terminal screenshot of `skillscore` flagging an over-broad
// allowed-tools grant (rule A6) for the README.
import { spawnSync } from 'child_process';
import { join, resolve } from 'path';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const OUT = join(resolve(import.meta.dirname, '..'), 'docs', 'assets', 'shots', 'allowed-tools.png');
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const out = spawnSync('/tmp/sk', ['/tmp/atdemo/pdf-form-filler', '--no-color'], {
  encoding: 'utf8',
  env: { ...process.env, NO_COLOR: '1' },
}).stdout.replace(/\n+$/, '');

const body = esc(out).split('\n').map((line) => {
  if (/Score:/.test(line))
    return line.replace(/(Score:\s*)(\d+\/100)(\s+Grade:\s*)(\S+)/,
      '<span style="color:#8b949e">$1</span><b style="color:#f0f6fc">$2</b><span style="color:#8b949e">$3</span><b style="color:#3fb950">$4</b>');
  if (/^\s+[A-G]\s+\S/.test(line)) {
    const over = /\b17\/19\b/.test(line);
    return line
      .replace(/(█+)(░+)/, '<span style="color:#4d9fff">$1</span><span style="color:#30363d">$2</span>')
      .replace(/(██████████)/, '<span style="color:#3fb950">$1</span>')
      .replace(/(\d+\/\d+)/, over ? '<span style="color:#e3b341">$1</span>' : '<span style="color:#8b949e">$1</span>');
  }
  if (/^\s*WARNING/.test(line))
    return line.replace(/(WARNING)(\s+)(A6_allowed_tools)(\s+)(line \d+)/,
      '<b style="color:#e3b341">$1</b>$2<b style="color:#f0f6fc">$3</b>$4<span style="color:#6b7684">$5</span>');
  if (/^\s*fix:/.test(line)) return `<span style="color:#6b7684">${line}</span>`;
  if (/approves every command/.test(line)) return `<span style="color:#e6edf3">${line}</span>`;
  if (/Tokens|description \(|full manifest/.test(line)) return `<span style="color:#6b7684">${line}</span>`;
  return line;
}).join('\n');

const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#010204;padding:26px;font-family:ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,monospace;width:940px}
  .win{background:#0d1117;border:1px solid #1e242d;border-radius:12px;overflow:hidden;box-shadow:0 16px 44px rgba(0,0,0,.5)}
  .bar{height:42px;background:#10151d;border-bottom:1px solid #1b2029;display:flex;align-items:center;padding:0 16px;position:relative}
  .dot{width:12px;height:12px;border-radius:50%;margin-right:8px}
  .r{background:#ff5f57}.y{background:#febc2e}.gg{background:#28c840}
  .title{position:absolute;left:0;right:0;text-align:center;color:#6b7684;font-size:13px}
  .body{padding:20px 22px;white-space:pre-wrap;word-break:break-word;color:#e6edf3;font-size:13px;line-height:1.6}
  .prompt{color:#3fb950}.cmd{color:#e6edf3}.cmdline{margin-bottom:14px}
</style></head><body>
  <div class="win">
    <div class="bar"><span class="dot r"></span><span class="dot y"></span><span class="dot gg"></span>
      <span class="title">skillscore pdf-form-filler/</span></div>
    <div class="body"><div class="cmdline"><span class="prompt">$</span> <span class="cmd">skillscore pdf-form-filler/</span></div>${body}</div>
  </div>
</body></html>`;

const b = await puppeteer.launch({ executablePath: CHROME, args: ['--no-sandbox', '--disable-setuid-sandbox'], headless: true });
const p = await b.newPage();
await p.setViewport({ width: 992, height: 300, deviceScaleFactor: 2 });
await p.setContent(html, { waitUntil: 'networkidle0' });
const box = await (await p.$('.win')).boundingBox();
await p.setViewport({ width: 992, height: Math.ceil(box.height) + 52, deviceScaleFactor: 2 });
await p.setContent(html, { waitUntil: 'networkidle0' });
await (await p.$('.win')).screenshot({ path: OUT });
await b.close();
console.log(`wrote ${OUT}`);
