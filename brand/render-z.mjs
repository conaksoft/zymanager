// Renders the ZyManager "Z family" icon concepts (siblings of ZyDisk) to 1024x1024 PNGs with alpha
// using headless Chrome, and builds a comparison sheet against the ZyDisk icon.
// Usage: node brand/render-z.mjs      (from the project root, or from brand/)
import puppeteer from 'puppeteer-core';
import sharp from 'sharp';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const out = path.join(here, 'z', 'options');
fs.mkdirSync(out, { recursive: true });

const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const ZYDISK =
  process.env.ZYDISK ||
  '/Users/kaanv/Desktop/raidrive-macos/raidrive_macos/macos/Runner/Assets.xcassets/AppIcon.appiconset/1024.png';

const concepts = await Promise.all([
  import('./z/z1-cache-stack.mjs'),
  import('./z/z2-gauge.mjs'),
  import('./z/z3-sweep.mjs'),
  import('./z/z4-chip.mjs'),
]);

// ---------------------------------------------------------------- 1024 renders
const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new' });
const page = await browser.newPage();
await page.setViewport({ width: 1024, height: 1024, deviceScaleFactor: 1 });

const bigPngs = [];
for (let i = 0; i < concepts.length; i++) {
  const svg = concepts[i].render();
  fs.writeFileSync(path.join(out, `z-${i + 1}.svg`), svg);
  await page.setContent(
    `<html><head><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>${svg}</body></html>`,
  );
  const buf = await page.screenshot({ type: 'png', omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  const png = await sharp(buf).ensureAlpha().png({ compressionLevel: 9 }).toBuffer();
  const file = path.join(out, `z-${i + 1}.png`);
  fs.writeFileSync(file, png);
  bigPngs.push(png);
  console.log(`wrote ${path.relative(process.cwd(), file)}  (${concepts[i].name})`);
}
await browser.close();

// ---------------------------------------------------------------- compare sheet
// Columns: ZyDisk reference + the 4 concepts. Rows: light and dark backgrounds.
// Each cell: 1024 render scaled to 320, then 128 / 32 / 16 px downsamples.
const columns = [{ name: 'ZyDisk (reference)', png: fs.readFileSync(ZYDISK) }].concat(
  concepts.map((c, i) => ({ name: `Z-${i + 1}  ${c.name}`, png: bigPngs[i] })),
);

const BIG = 320;
const SIZES = [128, 32, 16];
const PAD = 40;
const CELL_W = BIG + 24 + 128 + PAD;
const CELL_H = 64 + BIG + 24;
const ROW_H = CELL_H + PAD;
const SHEET_W = PAD + columns.length * CELL_W;
const SHEET_H = PAD + 2 * ROW_H;

const resize = (png, s) =>
  sharp(png).resize(s, s, { kernel: sharp.kernel.lanczos3, fit: 'fill' }).png().toBuffer();

const scaled = await Promise.all(
  columns.map(async (c) => ({
    big: await resize(c.png, BIG),
    small: await Promise.all(SIZES.map((s) => resize(c.png, s))),
  })),
);

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const label = (text, color, size = 26, weight = 600, w = 500) =>
  Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${size + 14}"><text x="0" y="${size}" font-family="-apple-system, Helvetica Neue, Helvetica, Arial, sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}">${esc(text)}</text></svg>`,
  );

const rows = [
  { bg: '#F2F2F7', fg: '#1C1C1E', name: 'Light #F2F2F7' },
  { bg: '#1E1E1E', fg: '#F2F2F7', name: 'Dark #1E1E1E' },
];

const composites = [];
rows.forEach((row, r) => {
  const y0 = PAD + r * ROW_H;
  composites.push({
    input: { create: { width: SHEET_W, height: ROW_H, channels: 4, background: row.bg } },
    left: 0,
    top: y0 - PAD / 2,
  });
  composites.push({ input: label(row.name, row.fg, 20, 500, 300), left: PAD, top: y0 - PAD / 2 + 6 });
  columns.forEach((c, i) => {
    const x0 = PAD + i * CELL_W;
    composites.push({ input: label(c.name, row.fg), left: x0, top: y0 + 20 });
    composites.push({ input: scaled[i].big, left: x0, top: y0 + 64 });
    composites.push({ input: label(`1024 → ${BIG}`, row.fg, 16, 400, 200), left: x0, top: y0 + 64 + BIG + 2 });
    let sy = y0 + 64;
    SIZES.forEach((s, k) => {
      composites.push({ input: scaled[i].small[k], left: x0 + BIG + 24, top: sy });
      composites.push({ input: label(`${s} px`, row.fg, 16, 400, 120), left: x0 + BIG + 24 + s + 10, top: sy + Math.max(0, s / 2 - 12) });
      sy += s + 26;
    });
  });
});

await sharp({ create: { width: SHEET_W, height: SHEET_H, channels: 4, background: '#8E8E93' } })
  .composite(composites)
  .png({ compressionLevel: 9 })
  .toFile(path.join(out, 'compare.png'));
console.log(`wrote ${path.relative(process.cwd(), path.join(out, 'compare.png'))}  (${SHEET_W}x${SHEET_H})`);
