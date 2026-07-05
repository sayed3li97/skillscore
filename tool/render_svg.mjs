#!/usr/bin/env node
// Render an SVG file to PNG at 2x via headless Chrome, so diagrams can be
// visually verified. Usage: node tool/render_svg.mjs <in.svg> <out.png> [w] [h]

import { readFileSync } from 'fs';
import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const [, , inPath, outPath, w = 1160, h = 460] = process.argv;

const svg = readFileSync(inPath, 'utf8');
const html = `<!DOCTYPE html><html><head><meta charset="utf-8">
<style>*{margin:0;padding:0}body{background:#010204}</style></head>
<body>${svg}</body></html>`;

const browser = await puppeteer.launch({
  executablePath: CHROME,
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
  headless: true,
});
const page = await browser.newPage();
await page.setViewport({ width: Number(w), height: Number(h), deviceScaleFactor: 2 });
await page.setContent(html, { waitUntil: 'networkidle0' });
// Let animations settle to a representative frame.
await new Promise((r) => setTimeout(r, 1200));
const el = await page.$('svg');
await el.screenshot({ path: outPath });
await browser.close();
console.log(`rendered ${outPath}`);
