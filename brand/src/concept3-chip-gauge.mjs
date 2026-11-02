// Concept 3 — "Chip Gauge": a memory chip fused with a ring gauge. The teal arc is the
// free / healthy portion; the dim remainder is used. Ring + bright arc stays legible at 16 px.
import { body, svgDoc, PAL } from './common.mjs';

export const name = 'Chip Gauge';

function arc(cx, cy, r, a0, a1) {
  const p = (a) => [cx + r * Math.cos((a * Math.PI) / 180), cy + r * Math.sin((a * Math.PI) / 180)];
  const [x0, y0] = p(a0), [x1, y1] = p(a1);
  const large = a1 - a0 > 180 ? 1 : 0;
  return `M${x0.toFixed(2)} ${y0.toFixed(2)} A${r} ${r} 0 ${large} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`;
}

export function render() {
  const defs = `
  <linearGradient id="c3Track" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1C1A58"/><stop offset="1" stop-color="#0A0C2C"/>
  </linearGradient>
  <linearGradient id="c3Arc" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0" stop-color="#22B8F0"/><stop offset="0.5" stop-color="#2EE6C5"/><stop offset="1" stop-color="#B4FFF3"/>
  </linearGradient>
  <linearGradient id="c3Chip" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#5B49C6"/><stop offset="0.5" stop-color="#2F2480"/><stop offset="1" stop-color="#171650"/>
  </linearGradient>
  <linearGradient id="c3ChipInner" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#1A1A55"/><stop offset="1" stop-color="#0B0D2A"/>
  </linearGradient>
  <linearGradient id="c3Pin" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9A8CF0"/><stop offset="1" stop-color="#3C2F96"/>
  </linearGradient>
  <radialGradient id="c3Core" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#DFFFF8"/><stop offset="0.35" stop-color="#2EE6C5"/><stop offset="1" stop-color="#2EE6C5" stop-opacity="0"/>
  </radialGradient>
  `;

  const cx = 512, cy = 512, R = 290, sw = 76;
  // gauge opens at the bottom: from 135deg to 405deg (270 degree sweep)
  const a0 = 135, a1 = 405;
  const freeEnd = a0 + 270 * 0.72;

  // chip
  const C = 150; // half size
  const pins = [];
  for (let i = -2; i <= 2; i++) {
    const o = i * 52;
    pins.push(`<rect x="${cx + o - 12}" y="${cy - C - 34}" width="24" height="40" rx="6" fill="url(#c3Pin)"/>`);
    pins.push(`<rect x="${cx + o - 12}" y="${cy + C - 6}" width="24" height="40" rx="6" fill="url(#c3Pin)"/>`);
    pins.push(`<rect x="${cx - C - 34}" y="${cy + o - 12}" width="40" height="24" rx="6" fill="url(#c3Pin)"/>`);
    pins.push(`<rect x="${cx + C - 6}" y="${cy + o - 12}" width="40" height="24" rx="6" fill="url(#c3Pin)"/>`);
  }

  // circuit traces on the die
  const traces = `
  <g fill="none" stroke="#2EE6C5" stroke-opacity="0.45" stroke-width="4" stroke-linecap="round">
    <path d="M${cx - 70} ${cy - 50} H${cx - 20} V${cy - 10}"/>
    <path d="M${cx + 70} ${cy + 50} H${cx + 20} V${cy + 10}"/>
    <path d="M${cx - 70} ${cy + 40} H${cx - 30}"/>
    <path d="M${cx + 70} ${cy - 40} H${cx + 30}"/>
  </g>`;

  const inner = `
  <ellipse cx="512" cy="820" rx="300" ry="60" fill="#05061A" opacity="0.55" filter="url(#b30)"/>

  <!-- ring track -->
  <g filter="url(#softShadow)">
    <path d="${arc(cx, cy, R, a0, a1)}" fill="none" stroke="url(#c3Track)" stroke-width="${sw}" stroke-linecap="round"/>
  </g>
  <path d="${arc(cx, cy, R, a0, a1)}" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="${sw + 4}" stroke-linecap="round" style="mix-blend-mode:multiply" opacity="0.5"/>
  <path d="${arc(cx, cy, R - sw / 2 + 3, a0, a1)}" fill="none" stroke="#fff" stroke-opacity="0.08" stroke-width="3" stroke-linecap="round"/>
  <!-- tick marks -->
  <g stroke="#9A8CF0" stroke-opacity="0.35" stroke-width="4" stroke-linecap="round">
    ${[0, 0.25, 0.5, 0.75, 1].map((f) => {
      const a = ((a0 + 270 * f) * Math.PI) / 180;
      const r0 = R + sw / 2 + 14, r1 = R + sw / 2 + 34;
      return `<line x1="${(cx + r0 * Math.cos(a)).toFixed(1)}" y1="${(cy + r0 * Math.sin(a)).toFixed(1)}" x2="${(cx + r1 * Math.cos(a)).toFixed(1)}" y2="${(cy + r1 * Math.sin(a)).toFixed(1)}"/>`;
    }).join('')}
  </g>

  <!-- free-space arc, glowing -->
  <path d="${arc(cx, cy, R, a0, freeEnd)}" fill="none" stroke="${PAL.teal}" stroke-width="${sw + 30}" stroke-linecap="round" opacity="0.45" filter="url(#b30)"/>
  <path d="${arc(cx, cy, R, a0, freeEnd)}" fill="none" stroke="url(#c3Arc)" stroke-width="${sw}" stroke-linecap="round"/>
  <path d="${arc(cx, cy, R - sw / 2 + 12, a0, freeEnd)}" fill="none" stroke="#fff" stroke-opacity="0.45" stroke-width="8" stroke-linecap="round"/>
  <!-- arc head highlight -->
  <circle cx="${(cx + R * Math.cos((freeEnd * Math.PI) / 180)).toFixed(1)}" cy="${(cy + R * Math.sin((freeEnd * Math.PI) / 180)).toFixed(1)}" r="40" fill="#DFFFF8" opacity="0.55" filter="url(#b14)"/>

  <!-- chip -->
  <g filter="url(#softShadow)">
    ${pins.join('')}
    <rect x="${cx - C}" y="${cy - C}" width="${C * 2}" height="${C * 2}" rx="34" fill="url(#c3Chip)"/>
  </g>
  <rect x="${cx - C}" y="${cy - C}" width="${C * 2}" height="${C}" rx="34" fill="url(#glassTop)"/>
  <rect x="${cx - C + 2}" y="${cy - C + 2}" width="${C * 2 - 4}" height="${C * 2 - 4}" rx="32" fill="none" stroke="#fff" stroke-opacity="0.2" stroke-width="2"/>
  <!-- die -->
  <rect x="${cx - 96}" y="${cy - 96}" width="192" height="192" rx="22" fill="url(#c3ChipInner)" stroke="#000" stroke-opacity="0.4" stroke-width="2"/>
  ${traces}
  <!-- glowing core -->
  <circle cx="${cx}" cy="${cy}" r="70" fill="url(#c3Core)" opacity="0.9"/>
  <circle cx="${cx}" cy="${cy}" r="22" fill="#EFFFFC"/>
  <circle cx="${cx}" cy="${cy}" r="40" fill="${PAL.teal}" opacity="0.6" filter="url(#b14)"/>
  `;
  return svgDoc(defs, body(inner, { glowOpacity: 0.22 }));
}
