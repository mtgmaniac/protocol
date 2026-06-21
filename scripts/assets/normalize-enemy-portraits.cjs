/**
 * Crop wide refs to 240×317 and downscale nearest-neighbor.
 * Usage: node scripts/normalize-enemy-portraits.cjs
 */
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const dir = path.join(root, 'public', 'enemies');

const TARGET_W = 240;
const TARGET_H = 317;
const RATIO = TARGET_W / TARGET_H;

const FILES = [
  'skitter-portrait.png',
  'mite-portrait.png',
  'stalker-portrait.png',
  'carapace-portrait.png',
  'brood-portrait.png',
  'spewer-portrait.png',
  'hive-boss-portrait.png',
  'void-wisp-portrait.png',
  'void-acolyte-portrait.png',
  'void-scribe-portrait.png',
  'void-binder-portrait.png',
  'void-glimmer-portrait.png',
  'void-channeler-portrait.png',
  'void-circlet-boss-portrait.png',
  'rift-macaque-portrait.png',
  'void-wolf-portrait.png',
  'eclipse-lynx-portrait.png',
  'thunder-bison-portrait.png',
  'eclipse-hyena-portrait.png',
  'ridge-badger-portrait.png',
  'void-reaver-portrait.png',
];

async function normalize(file) {
  const p = path.join(dir, file);
  if (!fs.existsSync(p)) {
    console.warn('skip missing', p);
    return;
  }
  const meta = await sharp(p).metadata();
  const w = meta.width ?? 1;
  const h = meta.height ?? 1;
  const wa = w / h;
  let left;
  let top;
  let cw;
  let ch;
  if (wa > RATIO) {
    ch = h;
    cw = Math.round(h * RATIO);
    left = Math.max(0, Math.round((w - cw) / 2));
    top = 0;
  } else {
    cw = w;
    ch = Math.round(w / RATIO);
    top = Math.max(0, Math.round((h - ch) / 2));
    left = 0;
  }
  const tmp = p + '.tmp.png';
  await sharp(p)
    .extract({ left, top, width: cw, height: ch })
    .resize(TARGET_W, TARGET_H, { kernel: sharp.kernel.nearest })
    .png()
    .toFile(tmp);
  fs.renameSync(tmp, p);
  console.log('ok', file);
}

(async () => {
  for (const f of FILES) {
    await normalize(f);
  }
})();
