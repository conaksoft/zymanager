// Z-4 "Chip": the Z sits on a memory-chip outline — rounded square with pins on all four
// sides and a corner marker — RAM manager.
import { body, svgDoc, compose, outline, WHITE } from './common-z.mjs';

export const name = 'Chip';

export function render() {
  const cx = 512, cy = 520, half = 236, rx = 44;
  const chip = `<rect x="${cx - half}" y="${cy - half}" width="${half * 2}" height="${half * 2}" rx="${rx}" ${outline(30)}/>`;

  // pins: 3 per side, thick rounded stubs
  const pinLen = 60, pinW = 32, gap = 112;
  const pins = [-gap, 0, gap]
    .map((o) => {
      const t = `<line x1="${cx + o}" y1="${cy - half - 15}" x2="${cx + o}" y2="${cy - half - 15 - pinLen}" ${outline(pinW)}/>`;
      const b = `<line x1="${cx + o}" y1="${cy + half + 15}" x2="${cx + o}" y2="${cy + half + 15 + pinLen}" ${outline(pinW)}/>`;
      const l = `<line x1="${cx - half - 15}" y1="${cy + o}" x2="${cx - half - 15 - pinLen}" y2="${cy + o}" ${outline(pinW)}/>`;
      const r = `<line x1="${cx + half + 15}" y1="${cy + o}" x2="${cx + half + 15 + pinLen}" y2="${cy + o}" ${outline(pinW)}/>`;
      return t + b + l + r;
    })
    .join('');

  // chip pin-1 marker
  const marker = `<circle cx="${cx - half + 58}" cy="${cy - half + 58}" r="13" fill="${WHITE}"/>`;

  const art = compose({
    behind: `${chip}${pins}${marker}`,
    z: { x: 386, y: 372, w: 252, h: 296, t: 66, d: 136 },
    gap: 24,
  });
  return svgDoc('', body(art, { liftCy: cy, liftR: 360 }));
}
