// Z-2 "Gauge": the Z inside a circular meter — a thin track ring with a thick filled arc
// showing used space / memory, open at the bottom like a dashboard gauge.
import { body, svgDoc, compose, arcPath, polar, outline, WHITE, INK } from './common-z.mjs';

export const name = 'Gauge';

export function render() {
  const cx = 512, cy = 520, R = 300;
  const a0 = -135, a1 = 135; // 270° gauge, opening at the bottom
  const fillTo = 62; // the "level" the thick arc reaches
  const track = `<path d="${arcPath(cx, cy, R, a0, a1)}" ${outline(26)}/>`;
  const level = `<path d="${arcPath(cx, cy, R, a0, fillTo)}" fill="none" stroke="${WHITE}" stroke-width="60" stroke-linecap="round"/>`;
  // end-of-level marker: a ring-dot sitting on the track
  const [nx, ny] = polar(cx, cy, R, fillTo);
  const marker = `<circle cx="${nx.toFixed(1)}" cy="${ny.toFixed(1)}" r="44" fill="${WHITE}"/><circle cx="${nx.toFixed(1)}" cy="${ny.toFixed(1)}" r="16" fill="${INK}"/>`;

  const art = compose({
    behind: `${track}${level}${marker}`,
    z: { x: 388, y: 372, w: 248, h: 296, t: 66, d: 136 },
    gap: 24,
  });
  return svgDoc('', body(art, { liftCy: cy, liftR: 360 }));
}
