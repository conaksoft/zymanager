// Shared building blocks for the ZyManager icon concepts.
// Canvas: 1024x1024, macOS Big Sur+ grid: 824x824 squircle body centred (100 px margin).

export const SIZE = 1024;
export const BODY = 824;
export const MARGIN = (SIZE - BODY) / 2; // 100

export const PAL = {
  indigo: '#0E1330',
  indigoDeep: '#080B1F',
  violet: '#3B2A8C',
  violetLight: '#5A45C4',
  teal: '#2EE6C5',
  cyan: '#22B8F0',
  amber: '#FFB547',
  white: '#FFFFFF',
};

/** Apple-style squircle (superellipse n=5) path centred at (cx, cy) with half-size a. */
export function squirclePath(cx = SIZE / 2, cy = SIZE / 2, a = BODY / 2, n = 5, steps = 720) {
  const pts = [];
  for (let i = 0; i < steps; i++) {
    const t = (i / steps) * Math.PI * 2;
    const c = Math.cos(t);
    const s = Math.sin(t);
    const x = cx + a * Math.sign(c) * Math.pow(Math.abs(c), 2 / n);
    const y = cy + a * Math.sign(s) * Math.pow(Math.abs(s), 2 / n);
    pts.push(`${x.toFixed(2)} ${y.toFixed(2)}`);
  }
  return `M${pts.join(' L')}Z`;
}

export const BODY_PATH = squirclePath();

/** Shared <defs>: body gradients, glows, blurs, noise, clip. */
export function commonDefs() {
  return `
  <clipPath id="bodyClip"><path d="${BODY_PATH}"/></clipPath>

  <!-- body: deep indigo -> violet, lit from the top-left -->
  <linearGradient id="bodyGrad" x1="0.1" y1="0" x2="0.9" y2="1">
    <stop offset="0" stop-color="#4A37A8"/>
    <stop offset="0.45" stop-color="#2A2070"/>
    <stop offset="1" stop-color="${PAL.indigo}"/>
  </linearGradient>
  <radialGradient id="bodyTopLight" cx="0.3" cy="0.05" r="0.9">
    <stop offset="0" stop-color="#8A7CFF" stop-opacity="0.55"/>
    <stop offset="0.5" stop-color="#8A7CFF" stop-opacity="0.08"/>
    <stop offset="1" stop-color="#8A7CFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="bodyVignette" cx="0.5" cy="0.55" r="0.75">
    <stop offset="0.55" stop-color="#000" stop-opacity="0"/>
    <stop offset="1" stop-color="#05061A" stop-opacity="0.55"/>
  </radialGradient>
  <linearGradient id="rimGrad" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.55"/>
    <stop offset="0.25" stop-color="#fff" stop-opacity="0.08"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0.02"/>
  </linearGradient>

  <!-- accents -->
  <linearGradient id="tealGrad" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#7FFFE6"/>
    <stop offset="0.45" stop-color="${PAL.teal}"/>
    <stop offset="1" stop-color="${PAL.cyan}"/>
  </linearGradient>
  <linearGradient id="tealGradV" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9CFFF0"/>
    <stop offset="0.4" stop-color="${PAL.teal}"/>
    <stop offset="1" stop-color="#149CD8"/>
  </linearGradient>
  <linearGradient id="slabGrad" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#6D5BD8"/>
    <stop offset="0.5" stop-color="#3B2A8C"/>
    <stop offset="1" stop-color="#201760"/>
  </linearGradient>
  <linearGradient id="slabDark" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2E2470"/>
    <stop offset="1" stop-color="#121640"/>
  </linearGradient>
  <linearGradient id="glassTop" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.38"/>
    <stop offset="0.5" stop-color="#fff" stop-opacity="0.06"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>

  <!-- blurs / glows -->
  <filter id="b6" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="b14" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
  <filter id="b30" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="30"/></filter>
  <filter id="b60" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="60"/></filter>
  <filter id="bodyShadow" x="-30%" y="-30%" width="160%" height="170%">
    <feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#000" flood-opacity="0.42"/>
  </filter>
  <filter id="softShadow" x="-40%" y="-40%" width="180%" height="200%">
    <feDropShadow dx="0" dy="18" stdDeviation="18" flood-color="#05061A" flood-opacity="0.6"/>
  </filter>
  <filter id="tightShadow" x="-40%" y="-40%" width="180%" height="200%">
    <feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#05061A" flood-opacity="0.55"/>
  </filter>
  <filter id="tealGlow" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="18" result="g"/>
    <feColorMatrix in="g" values="0 0 0 0 0.18  0 0 0 0 0.9  0 0 0 0 0.8  0 0 0 0.9 0" result="c"/>
    <feMerge><feMergeNode in="c"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>

  <!-- fine film grain, applied at low opacity over the body -->
  <filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="11" stitchTiles="stitch"/>
    <feColorMatrix type="saturate" values="0"/>
    <feComponentTransfer><feFuncA type="linear" slope="0.5" intercept="-0.1"/></feComponentTransfer>
  </filter>
  <!-- soft cloudy nebula for depth in the body -->
  <filter id="nebula" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.0025" numOctaves="3" seed="4"/>
    <feColorMatrix values="0 0 0 0 0.35  0 0 0 0 0.25  0 0 0 0 0.9  0 0 0 0.9 -0.25"/>
    <feGaussianBlur stdDeviation="10"/>
  </filter>
  `;
}

/** The squircle body with shadow, gradient, grain, nebula, rim light. Content goes on top, clipped. */
export function body(innerSvg, { glowColor = PAL.teal, glowOpacity = 0.35 } = {}) {
  return `
  <!-- drop shadow under the body -->
  <path d="${BODY_PATH}" fill="#000" opacity="0.35" transform="translate(0 20)" filter="url(#b30)"/>
  <g filter="url(#bodyShadow)"><path d="${BODY_PATH}" fill="url(#bodyGrad)"/></g>
  <g clip-path="url(#bodyClip)">
    <rect width="${SIZE}" height="${SIZE}" filter="url(#nebula)" opacity="0.35"/>
    <rect width="${SIZE}" height="${SIZE}" fill="url(#bodyTopLight)"/>
    <!-- diagonal light sweep -->
    <path d="M-100 420 L1124 -60 L1124 160 L-100 640 Z" fill="#fff" opacity="0.07" filter="url(#b60)"/>
    <!-- ambient accent glow behind the symbol -->
    <ellipse cx="512" cy="560" rx="300" ry="260" fill="${glowColor}" opacity="${glowOpacity}" filter="url(#b60)"/>
    ${innerSvg}
    <rect width="${SIZE}" height="${SIZE}" fill="url(#bodyVignette)"/>
    <rect width="${SIZE}" height="${SIZE}" filter="url(#grain)" opacity="0.18" style="mix-blend-mode:overlay"/>
    <!-- inner rim light -->
    <path d="${BODY_PATH}" fill="none" stroke="url(#rimGrad)" stroke-width="6"/>
    <path d="${BODY_PATH}" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="2" transform="translate(0 0)"/>
  </g>`;
}

export function svgDoc(defs, content) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <defs>${commonDefs()}${defs}</defs>${content}</svg>`;
}

/** Deterministic pseudo-random for particle scatter. */
export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}
