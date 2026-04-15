/**
 * Re-normalize existing public/heroes/*-portrait.png (transparent, aligned).
 * Use after manual edits or when you don't have the source sheet.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { normalizeHeroPortrait } from './hero-portrait-normalize.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const FILES = [
  'pulse-portrait.png',
  'combat-portrait.png',
  'shield-portrait.png',
  'avalanche-portrait.png',
  'medic-portrait.png',
  'engineer-portrait.png',
  'ghost-portrait.png',
  'breaker-portrait.png',
];

async function main() {
  const dir = path.join(root, 'public', 'heroes');
  for (const name of FILES) {
    const fp = path.join(dir, name);
    if (!fs.existsSync(fp)) {
      console.warn('skip missing', fp);
      continue;
    }
    const buf = fs.readFileSync(fp);
    const out = await normalizeHeroPortrait(buf);
    fs.writeFileSync(fp, out);
    console.log('normalized', fp);
  }
  console.log('Done. Run: npm run optimize-assets');
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
