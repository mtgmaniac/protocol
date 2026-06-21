/**
 * One-off / repeat: normalize style-match hero busts from Cursor assets into public/heroes/*-portrait.png.
 *
 * Expects files in: ~/.cursor/projects/c-Users-Kev-overload-protocol/assets/
 * Override: set HERO_STYLEMATCH_ASSETS to a folder containing the same filenames.
 *
 * Usage: node scripts/import-stylematch-hero-portraits.mjs
 */
import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import { normalizeHeroPortrait } from './hero-portrait-normalize.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

const DEFAULT_ASSETS = path.join(
  os.homedir(),
  '.cursor',
  'projects',
  'c-Users-Kev-overload-protocol',
  'assets',
);

const MAP = [
  ['pulse-portrait', 'hero-pulse-rematch.png'],
  ['combat-portrait', 'combat-portrait-fullbleed.png'],
  ['shield-portrait', 'hero-shield-stylematch.png'],
  ['medic-portrait', 'hero-medic-stylematch.png'],
  ['engineer-portrait', 'hero-engineer-stylematch.png'],
  ['ghost-portrait', 'hero-ghost-stylematch.png'],
];

async function main() {
  const assetsDir = (process.env.HERO_STYLEMATCH_ASSETS || DEFAULT_ASSETS).trim();
  if (!fs.existsSync(assetsDir)) {
    console.error('Assets folder not found:', assetsDir);
    console.error('Set HERO_STYLEMATCH_ASSETS or add files under the default path.');
    process.exit(1);
  }

  const outDir = path.join(root, 'public', 'heroes');
  fs.mkdirSync(outDir, { recursive: true });

  for (const [outBase, srcName] of MAP) {
    const src = path.join(assetsDir, srcName);
    if (!fs.existsSync(src)) {
      console.error('Missing source file:', src);
      process.exit(1);
    }
    const buf = fs.readFileSync(src);
    const out = await normalizeHeroPortrait(buf);
    const dest = path.join(outDir, `${outBase}.png`);
    fs.writeFileSync(dest, out);
    console.log('wrote', dest);
  }
  console.log('Done. Run: npm run optimize-assets');
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
