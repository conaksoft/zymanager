// Z-3 "Sweep": the Z's diagonal continues as a broom sweep — a thick crescent flowing out from
// under the bottom-left of the Z (like ZyDisk's arrow flows out of its Z), clearing small blocks
// that tumble away to the upper right.
import { body, svgDoc, compose, outline, WHITE } from './common-z.mjs';

export const name = 'Sweep';

export function render() {
  const z = { x: 330, y: 262, w: 290, h: 340, t: 74, d: 154 };

  // sweep: a filled crescent, thick where it leaves the Z, tapering into a brush tail at right.
  const sweep = `
  <path d="M396 560
           C 350 690, 430 772, 556 768
           C 660 764, 730 700, 756 600
           C 770 712, 690 812, 556 814
           C 410 818, 316 716, 396 560 Z"
        fill="${WHITE}" stroke="${WHITE}" stroke-width="12" stroke-linejoin="round"/>`;

  // blocks being swept: outlined squares scattering up-right from the sweep's tail
  const block = (x, y, s, rot) =>
    `<rect x="${x - s / 2}" y="${y - s / 2}" width="${s}" height="${s}" rx="${s * 0.2}" ${outline(24)} transform="rotate(${rot} ${x} ${y})"/>`;
  const blocks = [
    block(700, 560, 70, 12),
    block(780, 480, 52, -16),
    block(806, 588, 44, 28),
    `<circle cx="724" cy="440" r="11" fill="${WHITE}"/>`,
    `<circle cx="822" cy="676" r="9" fill="${WHITE}"/>`,
  ].join('');

  const art = compose({ behind: sweep, z, front: blocks, gap: 30 });
  return svgDoc('', body(art, { liftCx: 530, liftCy: 530, liftR: 340 }));
}
