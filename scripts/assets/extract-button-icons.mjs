/**
 * Extract frameless button icons from the baked btn_*_scifi.png textures.
 *
 * Strategy:
 *   1. Sample the source PNG and find the bbox of the dark inner panel
 *      (luminance < INNER_PANEL_MAX), which sits centered inside the frame.
 *   2. Inset the panel bbox by FRAME_MARGIN_PX to be safe distance from the
 *      frame's medium-blue edge.
 *   3. Within the inset rect, build an alpha mask from luminance: dark
 *      inner-panel pixels → transparent, bright glyph pixels → opaque (with
 *      linear blend across the threshold band for soft edges).
 *   4. Crop the result to the tight bbox of the glyph (any pixel with
 *      alpha > 32) and write to disk.
 *
 * Inputs:  ../../assets/ui/btn_<name>_scifi.png
 * Outputs: ../../assets/ui/icons/icon_<name>.png
 */
import sharp from 'sharp';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SRC_DIR = path.join(REPO_ROOT, 'assets', 'ui');
const OUT_DIR = path.join(REPO_ROOT, 'assets', 'ui', 'icons');

const BUTTONS = [
  { src: 'btn_help_scifi.png',     out: 'icon_help.png' },
  { src: 'btn_back_scifi.png',     out: 'icon_back.png' },
  { src: 'btn_reroll_scifi.png',   out: 'icon_reroll.png' },
  { src: 'btn_increase_scifi.png', out: 'icon_increase.png' },
  { src: 'btn_item_scifi.png',     out: 'icon_item.png' },
  { src: 'btn_debug_scifi.png',    out: 'icon_debug.png' },
  { src: 'btn_debug2_scifi.png',   out: 'icon_debug2.png' },
];

// Luminance thresholds (perceptual, 0–255).
const INNER_PANEL_MAX = 22;   // pixels darker than this count as inner panel
const ALPHA_DARK_LUM = 45;    // below → transparent
const ALPHA_FULL_LUM = 90;    // above → fully opaque; linear blend in between

// Extra inset added INSIDE the detected inner panel bbox to ensure we never
// keep frame pixels by accident.
const FRAME_MARGIN_PX = 4;

// Candidate seed offsets (fraction of width/height) for the inner panel
// flood-fill. We try each until one lands on a dark, opaque pixel.
const SEED_OFFSETS = [
  [0.28, 0.28], [0.72, 0.28], [0.28, 0.72], [0.72, 0.72],
  [0.5,  0.28], [0.5,  0.72], [0.28, 0.5],  [0.72, 0.5],
];

const lum = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;

async function extractOne(srcName, outName) {
  const srcPath = path.join(SRC_DIR, srcName);
  const { data, info } = await sharp(srcPath)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const w = info.width;
  const h = info.height;

  // Pass 1: find a seed pixel inside the dark inner panel, then flood-fill
  // its connected region. The bbox of that region defines the panel.
  const isPanelPixel = (x, y) => {
    const i = (y * w + x) * 4;
    if (data[i + 3] < 200) return false;
    return lum(data[i], data[i + 1], data[i + 2]) < INNER_PANEL_MAX;
  };
  let seedX = -1, seedY = -1;
  for (const [fx, fy] of SEED_OFFSETS) {
    const sx = Math.round(w * fx);
    const sy = Math.round(h * fy);
    if (isPanelPixel(sx, sy)) {
      seedX = sx;
      seedY = sy;
      break;
    }
  }
  if (seedX < 0) {
    throw new Error(`No inner-panel seed found in ${srcName}`);
  }
  const visited = new Uint8Array(w * h);
  const stack = [[seedX, seedY]];
  let pMinX = w, pMinY = h, pMaxX = -1, pMaxY = -1;
  while (stack.length > 0) {
    const [x, y] = stack.pop();
    if (x < 0 || y < 0 || x >= w || y >= h) continue;
    const idx = y * w + x;
    if (visited[idx]) continue;
    if (!isPanelPixel(x, y)) continue;
    visited[idx] = 1;
    if (x < pMinX) pMinX = x;
    if (x > pMaxX) pMaxX = x;
    if (y < pMinY) pMinY = y;
    if (y > pMaxY) pMaxY = y;
    stack.push([x + 1, y]);
    stack.push([x - 1, y]);
    stack.push([x, y + 1]);
    stack.push([x, y - 1]);
  }
  if (pMaxX < 0) {
    throw new Error(`Inner panel flood-fill empty for ${srcName}`);
  }
  // Inset to back away from the frame edge.
  pMinX = Math.min(w - 1, pMinX + FRAME_MARGIN_PX);
  pMinY = Math.min(h - 1, pMinY + FRAME_MARGIN_PX);
  pMaxX = Math.max(0,     pMaxX - FRAME_MARGIN_PX);
  pMaxY = Math.max(0,     pMaxY - FRAME_MARGIN_PX);

  // Pass 2: alpha-mask the inner area by luminance.
  // We also find the glyph's own bbox here so we can trim further.
  let gMinX = w, gMinY = h, gMaxX = -1, gMaxY = -1;
  const innerW = pMaxX - pMinX + 1;
  const innerH = pMaxY - pMinY + 1;
  const innerBuf = Buffer.alloc(innerW * innerH * 4);
  for (let yy = 0; yy < innerH; yy++) {
    for (let xx = 0; xx < innerW; xx++) {
      const sx = pMinX + xx;
      const sy = pMinY + yy;
      const i = (sy * w + sx) * 4;
      const oi = (yy * innerW + xx) * 4;
      const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
      let alpha = 0;
      if (a >= 200) {
        const L = lum(r, g, b);
        if (L >= ALPHA_FULL_LUM) {
          alpha = 255;
        } else if (L > ALPHA_DARK_LUM) {
          alpha = Math.round(((L - ALPHA_DARK_LUM) / (ALPHA_FULL_LUM - ALPHA_DARK_LUM)) * 255);
        }
      }
      innerBuf[oi]     = r;
      innerBuf[oi + 1] = g;
      innerBuf[oi + 2] = b;
      innerBuf[oi + 3] = alpha;
      if (alpha > 32) {
        if (xx < gMinX) gMinX = xx;
        if (xx > gMaxX) gMaxX = xx;
        if (yy < gMinY) gMinY = yy;
        if (yy > gMaxY) gMaxY = yy;
      }
    }
  }
  if (gMaxX < 0) {
    throw new Error(`No glyph pixels detected in ${srcName}`);
  }

  // Drop any connected component of opaque pixels smaller than this many
  // pixels. Glyphs are large; LED-accent leakage from the frame leaves
  // small specks. 8 is a safe minimum that still preserves the "?" dot.
  const MIN_COMPONENT_PX = 8;
  const innerVisited = new Uint8Array(innerW * innerH);
  for (let yy = 0; yy < innerH; yy++) {
    for (let xx = 0; xx < innerW; xx++) {
      const idx = yy * innerW + xx;
      if (innerVisited[idx]) continue;
      if (innerBuf[idx * 4 + 3] <= 32) continue;
      // BFS to find this component.
      const componentPixels = [];
      const compStack = [[xx, yy]];
      while (compStack.length > 0) {
        const [cx, cy] = compStack.pop();
        if (cx < 0 || cy < 0 || cx >= innerW || cy >= innerH) continue;
        const cidx = cy * innerW + cx;
        if (innerVisited[cidx]) continue;
        if (innerBuf[cidx * 4 + 3] <= 32) continue;
        innerVisited[cidx] = 1;
        componentPixels.push(cidx);
        compStack.push([cx + 1, cy]);
        compStack.push([cx - 1, cy]);
        compStack.push([cx, cy + 1]);
        compStack.push([cx, cy - 1]);
      }
      if (componentPixels.length < MIN_COMPONENT_PX) {
        for (const cidx of componentPixels) {
          innerBuf[cidx * 4 + 3] = 0;
        }
      }
    }
  }
  // Recompute glyph bbox after dropping small components.
  gMinX = innerW; gMinY = innerH; gMaxX = -1; gMaxY = -1;
  for (let yy = 0; yy < innerH; yy++) {
    for (let xx = 0; xx < innerW; xx++) {
      if (innerBuf[(yy * innerW + xx) * 4 + 3] > 32) {
        if (xx < gMinX) gMinX = xx;
        if (xx > gMaxX) gMaxX = xx;
        if (yy < gMinY) gMinY = yy;
        if (yy > gMaxY) gMaxY = yy;
      }
    }
  }
  if (gMaxX < 0) {
    throw new Error(`All glyph components dropped for ${srcName} — MIN_COMPONENT_PX too high?`);
  }

  // Add 1px breathing room around the glyph.
  gMinX = Math.max(0,           gMinX - 1);
  gMinY = Math.max(0,           gMinY - 1);
  gMaxX = Math.min(innerW - 1,  gMaxX + 1);
  gMaxY = Math.min(innerH - 1,  gMaxY + 1);

  const finalW = gMaxX - gMinX + 1;
  const finalH = gMaxY - gMinY + 1;
  const finalBuf = Buffer.alloc(finalW * finalH * 4);
  for (let yy = 0; yy < finalH; yy++) {
    for (let xx = 0; xx < finalW; xx++) {
      const sx = gMinX + xx;
      const sy = gMinY + yy;
      const si = (sy * innerW + sx) * 4;
      const oi = (yy * finalW + xx) * 4;
      finalBuf[oi]     = innerBuf[si];
      finalBuf[oi + 1] = innerBuf[si + 1];
      finalBuf[oi + 2] = innerBuf[si + 2];
      finalBuf[oi + 3] = innerBuf[si + 3];
    }
  }

  const outPath = path.join(OUT_DIR, outName);
  await sharp(finalBuf, { raw: { width: finalW, height: finalH, channels: 4 } })
    .png()
    .toFile(outPath);
  console.log(`  ${outName.padEnd(20)} ${String(finalW).padStart(3)}x${String(finalH).padStart(3)} (panel ${pMinX},${pMinY}–${pMaxX},${pMaxY})`);
}

(async () => {
  console.log(`Extracting button icons from ${SRC_DIR}`);
  console.log(`Writing to                  ${OUT_DIR}`);
  for (const b of BUTTONS) {
    await extractOne(b.src, b.out);
  }
})();
