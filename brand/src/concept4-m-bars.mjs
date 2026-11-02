// Concept 4 — "M Bars": an abstract "M" formed by five storage bars rising from a common
// baseline, lit teal at their tops. Doubles as a storage/memory meter. Bold silhouette at 16 px.
import { body, svgDoc, PAL } from './common.mjs';

export const name = 'M Bars';

export function render() {
  const defs = `
  <linearGradient id="c4Bar" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#C6FFF5"/>
    <stop offset="0.12" stop-color="#2EE6C5"/>
    <stop offset="0.55" stop-color="#22B8F0"/>
    <stop offset="1" stop-color="#3B2A8C"/>
  </linearGradient>
  <linearGradient id="c4BarSide" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#fff" stop-opacity="0.35"/>
    <stop offset="0.3" stop-color="#fff" stop-opacity="0.05"/>
    <stop offset="0.85" stop-color="#000" stop-opacity="0.05"/>
    <stop offset="1" stop-color="#000" stop-opacity="0.35"/>
  </linearGradient>
  <linearGradient id="c4Base" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#4B3AAE"/><stop offset="1" stop-color="#1A1650"/>
  </linearGradient>
  <linearGradient id="c4Reflect" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2EE6C5" stop-opacity="0.16"/><stop offset="1" stop-color="#2EE6C5" stop-opacity="0"/>
  </linearGradient>
  `;

  const baseline = 690;
  const w = 92, gap = 28, r = 30;
  const heights = [400, 300, 215, 300, 400];
  const n = heights.length;
  const total = n * w + (n - 1) * gap;
  const x0 = 512 - total / 2;

  let bars = '', caps = '', glows = '', reflections = '';
  heights.forEach((h, i) => {
    const x = x0 + i * (w + gap);
    const top = baseline - h;
    glows += `<rect x="${x - 10}" y="${top - 10}" width="${w + 20}" height="60" rx="${r}" fill="${PAL.teal}" opacity="0.7" filter="url(#b30)"/>`;
    bars += `
    <g filter="url(#softShadow)"><rect x="${x}" y="${top}" width="${w}" height="${h + 20}" rx="${r}" fill="url(#c4Bar)"/></g>
    <rect x="${x}" y="${top}" width="${w}" height="${h + 20}" rx="${r}" fill="url(#c4BarSide)"/>
    <rect x="${x + 1}" y="${top + 1}" width="${w - 2}" height="${h + 18}" rx="${r - 1}" fill="none" stroke="#fff" stroke-opacity="0.22" stroke-width="2"/>`;
    caps += `<rect x="${x + 14}" y="${top + 10}" width="${w - 28}" height="12" rx="6" fill="#fff" opacity="0.8"/>`;
    reflections += `<rect x="${x}" y="${baseline + 24}" width="${w}" height="90" rx="${r}" fill="url(#c4Reflect)"/>`;
  });

  // connecting "M" bridge: thin light line joining the bar tops, hints at the letterform
  const pts = heights.map((h, i) => `${x0 + i * (w + gap) + w / 2} ${baseline - h + 16}`).join(' L');

  const inner = `
  <ellipse cx="512" cy="${baseline + 60}" rx="360" ry="70" fill="#05061A" opacity="0.6" filter="url(#b30)"/>
  <!-- base plate -->
  <g filter="url(#softShadow)">
    <rect x="${x0 - 50}" y="${baseline}" width="${total + 100}" height="46" rx="23" fill="url(#c4Base)"/>
  </g>
  <rect x="${x0 - 50}" y="${baseline}" width="${total + 100}" height="23" rx="23" fill="url(#glassTop)"/>
  <rect x="${x0 - 48}" y="${baseline + 2}" width="${total + 96}" height="42" rx="21" fill="none" stroke="#fff" stroke-opacity="0.15" stroke-width="2"/>
  ${reflections}
  ${glows}
  ${bars}
  ${caps}
  <path d="M${pts}" fill="none" stroke="#fff" stroke-opacity="0.35" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" filter="url(#b6)"/>
  `;
  return svgDoc(defs, body(inner, { glowOpacity: 0.3 }));
}
