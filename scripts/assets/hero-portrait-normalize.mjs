/**
 * Normalize a hero bust for app-portrait-frame (240×317 viewBox):
 * - Knock out background (top-corner color + threshold; light pixels)
 * - Trim to opaque bounds
 * - Virtual zoom, then resize cover + bottom anchor (fills frame, crisp nearest-neighbor)
 * - Output transparent PNG
 */
import sharp from 'sharp';

export const PORTRAIT_W = 240;
export const PORTRAIT_H = 317;

/** Virtual zoom before cover-crop into frame (1 = prior tight crop). */
const PORTRAIT_ZOOM = 1.2;
/**
 * RGB distance² vs sampled backdrop to knock out background only when the pixel
 * is *almost* the same color (flat fill). Large values erase dark armor that is
 * merely “in the same ballpark” as the corners → black silhouettes.
 */
const BG_THRESH2 = 10 * 10;
/** Also treat very light neutrals as BG (checkerboard light squares). */
const LIGHT_MAX = 245;
const LIGHT_MIN_DIST2 = 18 * 18;

/**
 * @param {Buffer} inputPngOrRaw - cell extract or full portrait
 * @returns {Promise<Buffer>} PNG buffer 240×317, rgba
 */
export async function normalizeHeroPortrait(inputPngOrRaw) {
  const { data, info } = await sharp(inputPngOrRaw).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const w = info.width;
  const h = info.height;
  const ch = info.channels;
  if (ch !== 4) throw new Error('Expected RGBA');

  const sampleAvg = (x0, y0, rw, rh) => {
    let r = 0,
      g = 0,
      b = 0,
      n = 0;
    for (let y = y0; y < y0 + rh && y < h; y++) {
      for (let x = x0; x < x0 + rw && x < w; x++) {
        const i = (y * w + x) * ch;
        r += data[i];
        g += data[i + 1];
        b += data[i + 2];
        n++;
      }
    }
    return n ? [r / n, g / n, b / n] : [128, 128, 128];
  };

  const sw = Math.min(12, w);
  const sh = Math.min(12, h);
  const c1 = sampleAvg(0, 0, sw, sh);
  const c2 = sampleAvg(w - sw, 0, sw, sh);
  const c3 = sampleAvg(0, h - sh, sw, sh);
  const c4 = sampleAvg(w - sw, h - sh, sw, sh);
  const bgR = (c1[0] + c2[0] + c3[0] + c4[0]) / 4;
  const bgG = (c1[1] + c2[1] + c3[1] + c4[1]) / 4;
  const bgB = (c1[2] + c2[2] + c3[2] + c4[2]) / 4;

  const dist2bg = (r, g, b) => {
    const dr = r - bgR;
    const dg = g - bgG;
    const db = b - bgB;
    return dr * dr + dg * dg + db * db;
  };

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = (y * w + x) * ch;
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      let a = data[i + 3];
      if (a < 16) continue;
      if (dist2bg(r, g, b) < BG_THRESH2) {
        const sat = Math.max(r, g, b) - Math.min(r, g, b);
        /* Flat backdrop is near-gray; keep pixels with real hue spread (armor, skin). */
        if (sat > 18) continue;
        data[i + 3] = 0;
        continue;
      }
      if (r >= LIGHT_MAX && g >= LIGHT_MAX && b >= LIGHT_MAX) {
        data[i + 3] = 0;
        continue;
      }
      if (r >= 210 && g >= 210 && b >= 210 && dist2bg(r, g, b) < LIGHT_MIN_DIST2 * 4) {
        data[i + 3] = 0;
      }
    }
  }

  const rgbaBuf = Buffer.from(data);
  let trimmed = await sharp(rgbaBuf, {
    raw: { width: w, height: h, channels: 4 },
  })
    .png()
    .toBuffer();

  trimmed = await sharp(trimmed).trim({ threshold: 2 }).png().toBuffer();

  const meta = await sharp(trimmed).metadata();
  let tw = meta.width;
  let th = meta.height;
  if (!tw || !th) {
    return sharp({
      create: {
        width: PORTRAIT_W,
        height: PORTRAIT_H,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      },
    })
      .png({ compressionLevel: 9 })
      .toBuffer();
  }

  const zw = Math.max(1, Math.round(tw * PORTRAIT_ZOOM));
  const zh = Math.max(1, Math.round(th * PORTRAIT_ZOOM));
  const zoomed = await sharp(trimmed)
    .resize(zw, zh, { kernel: sharp.kernel.nearest })
    .png()
    .toBuffer();

  /** Cover + bottom anchor: fills 240×317, zooms in vs contain; nearest = crisp pixel upscale. */
  return sharp(zoomed)
    .resize(PORTRAIT_W, PORTRAIT_H, {
      fit: 'cover',
      position: 'bottom',
      kernel: sharp.kernel.nearest,
    })
    .png({ compressionLevel: 9, effort: 10 })
    .toBuffer();
}
