// Shared building blocks for the ZyManager "Z family" icon concepts.
// Style is matched to Conaksoft's ZyDisk icon (measured from its 1024 px asset):
//   - 824 px macOS squircle body, 100 px inset, no outer drop shadow
//   - near-black body gradient (#222328 top -> #0B0C10 bottom) with a faint lift behind the artwork
//   - pure white artwork: a solid, chunky, slightly italic Z plus thick-stroked outlined symbols
//   - soft white outer glow around all artwork, dark keyline gap where the Z overlaps other shapes

export const SIZE = 1024;
export const BODY = 824;
export const MARGIN = (SIZE - BODY) / 2; // 100, same as ZyDisk

export const WHITE = '#FFFFFF';
export const INK = '#141519'; // keyline / gap colour, close to the body behind the artwork
export const STROKE = 30; // outline stroke weight (ZyDisk cloud outline measures 27-33 px)

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

export function commonDefs() {
  return `
  <clipPath id="bodyClip"><path d="${BODY_PATH}"/></clipPath>
  <linearGradient id="zBody" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#232429"/>
    <stop offset="0.55" stop-color="#15161B"/>
    <stop offset="1" stop-color="#0A0B0F"/>
  </linearGradient>
  <radialGradient id="zLift" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#3A3F4B" stop-opacity="0.85"/>
    <stop offset="0.6" stop-color="#2A2E37" stop-opacity="0.25"/>
    <stop offset="1" stop-color="#2A2E37" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="zRim" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.16"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0.03"/>
  </linearGradient>
  <!-- soft white halo around the artwork, like ZyDisk -->
  <filter id="zGlow" x="-40%" y="-40%" width="180%" height="180%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="22" result="b1"/>
    <feGaussianBlur in="SourceAlpha" stdDeviation="7" result="b2"/>
    <feFlood flood-color="#FFFFFF" flood-opacity="0.34" result="c1"/>
    <feFlood flood-color="#FFFFFF" flood-opacity="0.30" result="c2"/>
    <feComposite in="c1" in2="b1" operator="in" result="g1"/>
    <feComposite in="c2" in2="b2" operator="in" result="g2"/>
    <feMerge><feMergeNode in="g1"/><feMergeNode in="g2"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  `;
}

/**
 * Chunky Z letterform as a filled polygon, bounding box w x h at (x, y).
 * t = bar thickness, d = horizontal width of the diagonal, skew = italic angle in degrees.
 * Corners are softened by a same-colour round-joined stroke of `round` px.
 */
export function zPath({ x = 0, y = 0, w = 300, h = 340, t = 74, d = 150 } = {}) {
  const p = [
    [0, 0], [w, 0], [w, t], [d, h - t], [w, h - t], [w, h], [0, h], [0, h - t], [w - d, t], [0, t],
  ];
  return 'M' + p.map(([px, py]) => `${(x + px).toFixed(1)} ${(y + py).toFixed(1)}`).join(' L') + 'Z';
}

/** Transform attribute that applies the italic skew about the glyph centre. */
function zTransform(opts, skew) {
  const cx = (opts.x ?? 0) + (opts.w ?? 300) / 2;
  const cy = (opts.y ?? 0) + (opts.h ?? 340) / 2;
  return `transform="translate(${cx} ${cy}) skewX(${skew}) translate(${-cx} ${-cy})"`;
}

/** Solid white Z (no keyline). */
export function zGlyph(opts = {}, { skew = -8, round = 10 } = {}) {
  const d = zPath(opts);
  return `
  <g ${zTransform(opts, skew)}>
    <path d="${d}" fill="${WHITE}" stroke="${WHITE}" stroke-width="${round}" stroke-linejoin="round"/>
  </g>`;
}

/**
 * Compose a scene: `behind` shapes are masked with a gap around the Z (ZyDisk's dark keyline
 * where the Z crosses the cloud), then the Z, then `front` shapes. Only the overlap shows a gap;
 * against the plain body the Z has no outline, exactly like the reference.
 */
let maskSeq = 0;
export function compose({ behind = '', front = '', z = {}, skew = -8, gap = 28, round = 10 }) {
  const id = `zgap${maskSeq++}`;
  const d = zPath(z);
  const tf = zTransform(z, skew);
  return `
  <mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="${SIZE}" height="${SIZE}">
    <rect width="${SIZE}" height="${SIZE}" fill="#fff"/>
    <g ${tf}><path d="${d}" fill="#000" stroke="#000" stroke-width="${gap + round}" stroke-linejoin="round"/></g>
  </mask>
  <g mask="url(#${id})">${behind}</g>
  ${zGlyph(z, { skew, round })}
  ${front}`;
}

/** Squircle body + lift + artwork (glowed) + rim. */
export function body(artSvg, { liftCx = 512, liftCy = 520, liftR = 330 } = {}) {
  return `
  <g clip-path="url(#bodyClip)">
    <path d="${BODY_PATH}" fill="url(#zBody)"/>
    <ellipse cx="${liftCx}" cy="${liftCy}" rx="${liftR}" ry="${liftR * 0.95}" fill="url(#zLift)"/>
    <g filter="url(#zGlow)">${artSvg}</g>
    <path d="${BODY_PATH}" fill="none" stroke="url(#zRim)" stroke-width="4"/>
  </g>`;
}

export function svgDoc(defs, content) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <defs>${commonDefs()}${defs}</defs>${content}</svg>`;
}

/** Helper: thick white outline stroke attributes. */
export const outline = (w = STROKE) =>
  `fill="none" stroke="${WHITE}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"`;

/** 4-point sparkle centred at (cx, cy) with outer radius r. */
export function sparkle(cx, cy, r, inner = 0.28) {
  const ri = r * inner;
  const pts = [];
  for (let i = 0; i < 8; i++) {
    const a = (i * Math.PI) / 4 - Math.PI / 2;
    const rr = i % 2 === 0 ? r : ri;
    pts.push(`${(cx + rr * Math.cos(a)).toFixed(1)} ${(cy + rr * Math.sin(a)).toFixed(1)}`);
  }
  return `<path d="M${pts.join(' L')}Z" fill="${WHITE}" stroke="${WHITE}" stroke-width="${Math.max(2, r * 0.12)}" stroke-linejoin="round"/>`;
}

/** Polar helper for arcs. */
export const polar = (cx, cy, r, deg) => {
  const a = ((deg - 90) * Math.PI) / 180;
  return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
};
export function arcPath(cx, cy, r, a0, a1) {
  const [x0, y0] = polar(cx, cy, r, a0);
  const [x1, y1] = polar(cx, cy, r, a1);
  const large = a1 - a0 > 180 ? 1 : 0;
  return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${r} ${r} 0 ${large} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
}
