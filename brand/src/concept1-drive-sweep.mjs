// Concept 1 — "Drive Sweep": a glowing SSD slab with stale layers being lifted / swept away
// into teal light. Reads as a drive with a bright teal bar at tiny sizes.
import { body, svgDoc, rng, PAL } from './common.mjs';

export const name = 'Drive Sweep';

function particles() {
  const r = rng(101);
  let out = '';
  for (let i = 0; i < 46; i++) {
    const t = r();
    const x = 560 + t * 330 + (r() - 0.5) * 90;
    const y = 470 - t * 250 + (r() - 0.5) * 70;
    const rad = 3 + r() * 9 * (1 - t * 0.6);
    const op = 0.25 + (1 - t) * 0.7;
    out += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${rad.toFixed(1)}" fill="#BFFFF2" opacity="${op.toFixed(2)}"/>`;
  }
  return out;
}

export function render() {
  const defs = `
  <linearGradient id="c1Shell" x1="0" y1="0" x2="0.3" y2="1">
    <stop offset="0" stop-color="#2F2A74"/>
    <stop offset="0.35" stop-color="#171A4E"/>
    <stop offset="1" stop-color="#090B26"/>
  </linearGradient>
  <linearGradient id="c1ShellSide" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#0E1034"/>
    <stop offset="1" stop-color="#05061A"/>
  </linearGradient>
  <linearGradient id="c1Sheet" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#2EE6C5" stop-opacity="0.95"/>
    <stop offset="0.7" stop-color="#22B8F0" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#22B8F0" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="c1Bar" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#9CFFF0"/>
    <stop offset="0.6" stop-color="#2EE6C5"/>
    <stop offset="1" stop-color="#22B8F0"/>
  </linearGradient>
  <linearGradient id="c1BarDim" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#1B1A52"/>
    <stop offset="1" stop-color="#0E1330"/>
  </linearGradient>
  `;

  // Drive slab geometry (front face), slight 3D thickness below.
  const X = 212, Y = 392, W = 600, H = 300, R = 44, D = 26;

  const inner = `
  <!-- soft floor glow under the drive -->
  <ellipse cx="512" cy="720" rx="330" ry="60" fill="#05061A" opacity="0.55" filter="url(#b30)"/>
  <ellipse cx="512" cy="700" rx="260" ry="40" fill="${PAL.teal}" opacity="0.35" filter="url(#b30)"/>

  <!-- lifted plates (old cache layers peeling off the drive, dissolving into light) -->
  ${[0, 1, 2].map((k) => {
    const lift = 28 + k * 50, shift = 34 + k * 44, op = 0.95 - k * 0.28;
    const ww = W - 90 - k * 70, hh = 30 - k * 4;
    const px = X + 45 + shift, py = Y - lift - hh;
    return `<g opacity="${op}" filter="url(#tealGlow)">
      <rect x="${px}" y="${py}" width="${ww}" height="${hh}" rx="${hh / 2}" fill="url(#c1Sheet)"/>
      <rect x="${px}" y="${py}" width="${ww * 0.8}" height="${hh / 2}" rx="${hh / 4}" fill="#fff" opacity="0.28"/>
    </g>`;
  }).join('')}
  ${particles()}

  <!-- drive body: thickness, then face -->
  <g filter="url(#softShadow)">
    <rect x="${X}" y="${Y + D}" width="${W}" height="${H}" rx="${R}" fill="url(#c1ShellSide)"/>
    <rect x="${X}" y="${Y}" width="${W}" height="${H}" rx="${R}" fill="url(#c1Shell)"/>
  </g>
  <!-- face glass highlight -->
  <rect x="${X}" y="${Y}" width="${W}" height="${H * 0.5}" rx="${R}" fill="url(#glassTop)"/>
  <rect x="${X + 2}" y="${Y + 2}" width="${W - 4}" height="${H - 4}" rx="${R - 2}" fill="none" stroke="#fff" stroke-opacity="0.18" stroke-width="2"/>
  <!-- screw-like corner dots for drive feel -->
  <g fill="#0B0E2A" opacity="0.7">
    <circle cx="${X + 40}" cy="${Y + 40}" r="7"/><circle cx="${X + W - 40}" cy="${Y + 40}" r="7"/>
    <circle cx="${X + 40}" cy="${Y + H - 40}" r="7"/><circle cx="${X + W - 40}" cy="${Y + H - 40}" r="7"/>
  </g>
  <g fill="#fff" opacity="0.25">
    <circle cx="${X + 38}" cy="${Y + 38}" r="3"/><circle cx="${X + W - 42}" cy="${Y + 38}" r="3"/>
    <circle cx="${X + 38}" cy="${Y + H - 42}" r="3"/><circle cx="${X + W - 42}" cy="${Y + H - 42}" r="3"/>
  </g>

  <!-- capacity bar: track + lit "free space" portion -->
  <rect x="${X + 64}" y="${Y + 132}" width="${W - 128}" height="64" rx="32" fill="url(#c1BarDim)"/>
  <rect x="${X + 64}" y="${Y + 132}" width="${W - 128}" height="64" rx="32" fill="none" stroke="#000" stroke-opacity="0.4" stroke-width="2"/>
  <g filter="url(#tealGlow)">
    <rect x="${X + 64}" y="${Y + 132}" width="${(W - 128) * 0.7}" height="64" rx="32" fill="url(#c1Bar)"/>
  </g>
  <rect x="${X + 70}" y="${Y + 138}" width="${(W - 128) * 0.7 - 12}" height="24" rx="12" fill="#fff" opacity="0.35"/>
  <!-- activity LED -->
  <circle cx="${X + W - 64}" cy="${Y + 164}" r="20" fill="${PAL.teal}" opacity="0.5" filter="url(#b14)"/>
  <circle cx="${X + W - 64}" cy="${Y + 164}" r="10" fill="#C8FFF4"/>
  <!-- status slots below the bar -->
  <g fill="#fff" opacity="0.12">
    ${[0, 1, 2, 3].map((k) => `<rect x="${X + 64 + k * 60}" y="${Y + 222}" width="44" height="12" rx="6"/>`).join('')}
  </g>
  `;
  return svgDoc(defs, body(inner, { glowOpacity: 0.3 }));
}
