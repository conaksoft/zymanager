// Z-1 "Cache Stack": the Z stands on a stack of three cache slabs (outlined rounded slabs,
// a sibling of ZyDisk's disk stack) while small sparkles and dust lift off the top — cleaning caches.
import { body, svgDoc, compose, outline, sparkle, WHITE } from './common-z.mjs';

export const name = 'Cache Stack';

export function render() {
  // slabs: wide rounded slabs stacked with gaps, the top one slightly lifted (being cleared)
  const slabW = 440, slabH = 74, rx = 37, cx = 512;
  const slabs = [560, 630, 700]
    .map((y) => `<rect x="${cx - slabW / 2}" y="${y}" width="${slabW}" height="${slabH}" rx="${rx}" ${outline()}/>`)
    .join('');

  // sparkles lifting off, top-right, decreasing size with height
  const sparks = [
    sparkle(712, 300, 44),
    sparkle(640, 230, 28),
    sparkle(756, 392, 22),
    `<circle cx="694" cy="214" r="9" fill="${WHITE}"/>`,
    `<circle cx="760" cy="268" r="7" fill="${WHITE}"/>`,
  ].join('');

  const art = compose({
    behind: slabs,
    z: { x: 380, y: 290, w: 264, h: 318, t: 70, d: 146 },
    front: sparks,
  });
  return svgDoc('', body(art, { liftCy: 520 }));
}
