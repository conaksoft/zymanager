// Renders the ZyManager icon concepts to PNG (1024x1024, alpha) with headless Chrome
// and builds a small-size legibility contact sheet.
// Usage: node brand/render.mjs      (from the project root, or from brand/)
import puppeteer from 'puppeteer-core';
import sharp from 'sharp';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const out = path.join(here, 'options');
fs.mkdirSync(out, { recursive: true });

const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const concepts = await Promise.all([
  import('./src/concept1-drive-sweep.mjs'),
  import('./src/concept2-cache-stack.mjs'),
  import('./src/concept3-chip-gauge.mjs'),
  import('./src/concept4-m-bars.mjs'),
]);

// ---------------------------------------------------------------- 1024 renders
const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new' });
const page = await browser.newPage();
await page.setViewport({ width: 1024, height: 1024, deviceScaleFactor: 1 });

const bigPngs = [];
for (let i = 0; i < concepts.length; i++) {
  const svg = concepts[i].render();
  await page.setContent(`<html><head><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>${svg}</body></html>`);
  const buf = await page.screenshot({ type: 'png', omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  const png = await sharp(buf).ensureAlpha().png({ compressionLevel: 9 }).toBuffer();
  const file = path.join(out, `option-${i + 1}.png`);
  fs.writeFileSync(file, png);
  bigPngs.push(png);
  console.log(`wrote ${path.relative(process.cwd(), file)}  (${concepts[i].name})`);
}
await browser.close();

// ---------------------------------------------------------------- contact sheet
// Per concept column: 1024 render + a stack of 128 / 32 / 16 px downsamples, on light and dark rows.
const SIZES = [128, 32, 16];
const PAD = 48;
const CELL_W = 1024 + 40 + 160 + PAD; // icon + gap + small column + pad
const CELL_H = 1024 + 120;            // room for the label
const ROW_H = CELL_H + PAD;
const SHEET_W = PAD + concepts.length * CELL_W;
const SHEET_H = PAD + 2 * ROW_H;

const downs = await Promise.all(
  bigPngs.map((png) =>
    Promise.all(
      SIZES.map((s) =>
        sharp(png).resize(s, s, { kernel: sharp.kernel.lanczos3, fit: 'fill' }).png().toBuffer(),
      ),
    ),
  ),
);

const label = (text, color) =>
  Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="80"><text x="0" y="56" font-family="-apple-system, Helvetica Neue, Helvetica, Arial, sans-serif" font-size="52" font-weight="600" fill="${color}">${text}</text></svg>`,
  );
const sizeLabel = (text, color) =>
  Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="160" height="30"><text x="0" y="22" font-family="-apple-system, Helvetica Neue, Helvetica, Arial, sans-serif" font-size="22" fill="${color}" opacity="0.8">${text}</text></svg>`,
  );

const rows = [
  { bg: '#F2F2F7', fg: '#1C1C1E', name: 'Light' },
  { bg: '#1E1E1E', fg: '#F2F2F7', name: 'Dark' },
];

const composites = [];
rows.forEach((row, r) => {
  const y0 = PAD + r * ROW_H;
  composites.push({
    input: { create: { width: SHEET_W, height: ROW_H - PAD / 2, channels: 4, background: row.bg } },
    left: 0,
    top: y0 - PAD / 4,
  });
  concepts.forEach((c, i) => {
    const x0 = PAD + i * CELL_W;
    composites.push({ input: label(`${i + 1}  ${c.name}  —  ${row.name}`, row.fg), left: x0, top: y0 });
    composites.push({ input: bigPngs[i], left: x0, top: y0 + 90 });
    let sy = y0 + 90;
    SIZES.forEach((s, k) => {
      composites.push({ input: downs[i][k], left: x0 + 1024 + 40, top: sy });
      composites.push({ input: sizeLabel(`${s} px`, row.fg), left: x0 + 1024 + 40, top: sy + s + 6 });
      sy += s + 56;
    });
  });
});

await sharp({ create: { width: SHEET_W, height: SHEET_H, channels: 4, background: '#8E8E93' } })
  .composite(composites)
  .png({ compressionLevel: 9 })
  .toFile(path.join(out, 'small-preview.png'));
console.log(`wrote ${path.relative(process.cwd(), path.join(out, 'small-preview.png'))}  (${SHEET_W}x${SHEET_H})`);
