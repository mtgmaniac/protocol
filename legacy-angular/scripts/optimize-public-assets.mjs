/**
 * Lossless image optimization for everything under public/:
 * 1) Re-writes each PNG with maximum lossless zlib settings (same pixels, often smaller file).
 * 2) Writes a sibling .webp for each PNG using WebP lossless (usually 25–55% smaller on the wire).
 *
 * Run from repo root: npm run optimize-assets
 *
 * After a successful run, set RASTER_EXT to '.webp' in src/app/data/sprites.data.ts so the app
 * loads the WebP files (still lossless). Until then, keep RASTER_EXT '.png' to use originals.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const publicDir = path.join(root, 'public');

function walkPngFiles(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) walkPngFiles(full, acc);
    else if (ent.name.toLowerCase().endsWith('.png')) acc.push(full);
  }
  return acc;
}

function fmtKb(n) {
  return `${(n / 1024).toFixed(1)} KB`;
}

async function main() {
  const files = walkPngFiles(publicDir);
  if (files.length === 0) {
    console.log('optimize-public-assets: no PNG files under public/ — nothing to do.');
    return;
  }

  let savedPng = 0;
  let webpTotal = 0;

  for (const fp of files) {
    const before = fs.statSync(fp).size;
    const buf = fs.readFileSync(fp);
    const dir = path.dirname(fp);
    const base = path.basename(fp, '.png');
    const webpPath = path.join(dir, `${base}.webp`);

    const optimizedPng = await sharp(buf)
      .png({
        compressionLevel: 9,
        effort: 10,
        adaptiveFiltering: true,
      })
      .toBuffer();

    fs.writeFileSync(fp, optimizedPng);
    const afterPng = optimizedPng.length;
    savedPng += before - afterPng;

    await sharp(buf).webp({ lossless: true, effort: 6 }).toFile(webpPath);
    webpTotal += fs.statSync(webpPath).size;

    console.log(
      `${path.relative(root, fp)}: PNG ${fmtKb(before)} → ${fmtKb(afterPng)}; WebP lossless ${fmtKb(fs.statSync(webpPath).size)}`,
    );
  }

  console.log(
    `\noptimize-public-assets: ${files.length} file(s). PNG bytes saved (vs original on disk): ${fmtKb(Math.max(0, savedPng))}.`,
  );
  console.log(
    'Next step: set RASTER_EXT to \'.webp\' in src/app/data/sprites.data.ts (lossless, smaller downloads).',
  );
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
