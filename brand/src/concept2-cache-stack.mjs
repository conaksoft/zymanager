// Concept 2 — "Cache Stack": three isometric cache slabs; the top one is lit teal and
// dissolving into particles (regenerable cache being released). High-contrast stacked silhouette.
import { body, svgDoc, rng, PAL } from './common.mjs';

export const name = 'Cache Stack';

// Isometric slab: centre (cx, cy) of the top face, half-width hw, half-depth hd, thickness t.
function slab(cx, cy, hw, hd, t, top, left, right, extra = '') {
  const L = `${cx - hw} ${cy}`, T = `${cx} ${cy - hd}`, R = `${cx + hw} ${cy}`, B = `${cx} ${cy + hd}`;
  return `
  <g ${extra}>
    <path d="M${cx - hw} ${cy} L${cx} ${cy + hd} L${cx} ${cy + hd + t} L${cx - hw} ${cy + t} Z" fill="${left}"/>
    <path d="M${cx + hw} ${cy} L${cx} ${cy + hd} L${cx} ${cy + hd + t} L${cx + hw} ${cy + t} Z" fill="${right}"/>
    <path d="M${L} L${T} L${R} L${B} Z" fill="${top}"/>
  </g>`;
}

function particles() {
  const r = rng(202);
  let out = '';
  for (let i = 0; i < 60; i++) {
    const t = r();
    const x = 420 + r() * 300 + t * 120;
    const y = 330 - t * 230 + (r() - 0.5) * 60;
    const rad = 2.5 + r() * 8 * (1 - t * 0.7);
    const op = 0.2 + (1 - t) * 0.75;
    const square = r() > 0.6;
    out += square
      ? `<rect x="${(x - rad).toFixed(1)}" y="${(y - rad).toFixed(1)}" width="${(rad * 2).toFixed(1)}" height="${(rad * 2).toFixed(1)}" rx="${(rad * 0.3).toFixed(1)}" fill="#BFFFF2" opacity="${op.toFixed(2)}" transform="rotate(${(r() * 40).toFixed(0)} ${x.toFixed(1)} ${y.toFixed(1)})"/>`
      : `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${rad.toFixed(1)}" fill="#BFFFF2" opacity="${op.toFixed(2)}"/>`;
  }
  return out;
}

export function render() {
  const defs = `
  <linearGradient id="c2TopA" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#7A69E6"/><stop offset="1" stop-color="#4A38AE"/>
  </linearGradient>
  <linearGradient id="c2TopB" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#5C4BCB"/><stop offset="1" stop-color="#342680"/>
  </linearGradient>
  <linearGradient id="c2Left" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2E2478"/><stop offset="1" stop-color="#15153F"/>
  </linearGradient>
  <linearGradient id="c2Right" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1E1A5A"/><stop offset="1" stop-color="#0C0E2C"/>
  </linearGradient>
  <linearGradient id="c2TealTop" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#B4FFF3"/><stop offset="0.45" stop-color="#2EE6C5"/><stop offset="1" stop-color="#22B8F0"/>
  </linearGradient>
  <linearGradient id="c2TealLeft" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1FC9AC"/><stop offset="1" stop-color="#0F8FA8"/>
  </linearGradient>
  <linearGradient id="c2TealRight" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#17A8D8"/><stop offset="1" stop-color="#0B6FA0"/>
  </linearGradient>
  <linearGradient id="c2Dissolve" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0.55" stop-color="#fff" stop-opacity="1"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <mask id="c2DissolveMask"><rect x="200" y="100" width="700" height="500" fill="url(#c2Dissolve)"/></mask>
  `;

  const cx = 512, hw = 280, hd = 150, t = 70;
  const inner = `
  <ellipse cx="512" cy="760" rx="330" ry="70" fill="#05061A" opacity="0.6" filter="url(#b30)"/>
  <ellipse cx="512" cy="700" rx="230" ry="50" fill="${PAL.teal}" opacity="0.25" filter="url(#b30)"/>

  <!-- bottom slab -->
  ${slab(cx, 575, hw, hd, t, 'url(#c2TopB)', 'url(#c2Left)', 'url(#c2Right)', 'filter="url(#softShadow)"')}
  <!-- middle slab -->
  ${slab(cx, 480, hw, hd, t, 'url(#c2TopA)', 'url(#c2Left)', 'url(#c2Right)', 'filter="url(#softShadow)"')}
  <!-- grooves / edge highlights -->
  <path d="M${cx - hw} 575 L${cx} ${575 - hd} L${cx + hw} 575" fill="none" stroke="#fff" stroke-opacity="0.25" stroke-width="3"/>
  <path d="M${cx - hw} 480 L${cx} ${480 - hd} L${cx + hw} 480" fill="none" stroke="#fff" stroke-opacity="0.3" stroke-width="3"/>

  <!-- top slab: teal, glowing, dissolving to the right -->
  <g filter="url(#tealGlow)" mask="url(#c2DissolveMask)">
    ${slab(cx, 385, hw, hd, t, 'url(#c2TealTop)', 'url(#c2TealLeft)', 'url(#c2TealRight)', '')}
  </g>
  <!-- top face sheen -->
  <path d="M${cx - hw} 385 L${cx} ${385 - hd} L${cx + hw * 0.35} ${385 - hd * 0.45} L${cx - hw * 0.4} ${385 + hd * 0.35} Z" fill="#fff" opacity="0.22" mask="url(#c2DissolveMask)"/>
  <path d="M${cx - hw} 385 L${cx} ${385 - hd} L${cx + hw} 385" fill="none" stroke="#fff" stroke-opacity="0.75" stroke-width="3" mask="url(#c2DissolveMask)"/>
  <!-- bright core glow on the dissolving edge -->
  <ellipse cx="${cx + 170}" cy="330" rx="120" ry="70" fill="#9CFFF0" opacity="0.5" filter="url(#b30)"/>
  ${particles()}
  `;
  return svgDoc(defs, body(inner, { glowOpacity: 0.28 }));
}
