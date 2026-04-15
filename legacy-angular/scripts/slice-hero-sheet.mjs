/**
 * Slice a hero sheet, then normalize each cell (transparent BG, 240×317, aligned bust).
 *
 * Layout (auto-detected from aspect ratio):
 * - Wide strip: 8 columns × 1 row (e.g. 1024×202)
 * - Grid: 4 columns × 2 rows
 *
 * Gemini 8×2 + labels under columns:
 *   --8x2-top | --8x2-bottom  — 8 columns, two portrait rows; strip bottom for caption text;
 *   use only top or bottom portrait row (--crop-bottom-pct default 11).
 *
 * Hero order (left→right, top→bottom): pulse, combat, shield, avalanche, medic, engineer, ghost, breaker.
 *
 * Usage: node scripts/slice-hero-sheet.mjs <path-to-sheet.png>
 * Force layout: node scripts/slice-hero-sheet.mjs <path> --8x1 | --4x2
 * Gemini sheet: node scripts/slice-hero-sheet.mjs <path> --8x2-top [--crop-bottom-pct=11] [--crop-bottom-px=64]
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';
import { normalizeHeroPortrait } from './hero-portrait-normalize.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

const HERO_ORDER = [
  'pulse-portrait',
  'combat-portrait',
  'shield-portrait',
  'avalanche-portrait',
  'medic-portrait',
  'engineer-portrait',
  'ghost-portrait',
  'breaker-portrait',
];

function detectLayout(w, h) {
  const ratio = w / h;
  // Wide single-row sheets; 4×2 grids are squarer (ratio ~2 or less).
  if (ratio > 2.8) return { cols: 8, rows: 1 };
  return { cols: 4, rows: 2 };
}

function buildCells(cols, rows) {
  const cells = [];
  let i = 0;
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      cells.push({ file: HERO_ORDER[i++], col, row });
    }
  }
  return cells;
}

function parseNumFlag(argv, prefix) {
  const a = argv.find(x => x.startsWith(prefix));
  if (!a) return null;
  const v = a.slice(prefix.length);
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : null;
}

async function main() {
  const argv = process.argv.slice(2);
  const flags = new Set(argv.filter(a => a === '--8x1' || a === '--4x2' || a === '--8x2-top' || a === '--8x2-bottom'));
  const pathArgs = argv.filter(a => !a.startsWith('--'));
  const arg = pathArgs[0];
  if (!arg || !fs.existsSync(arg)) {
    console.error(
      'Usage: node scripts/slice-hero-sheet.mjs <sheet.png> [--8x1|--4x2|--8x2-top|--8x2-bottom] [--crop-bottom-pct=11] [--crop-bottom-px=N]',
    );
    process.exit(1);
  }

  const meta = await sharp(arg).metadata();
  const w = meta.width;
  const h = meta.height;
  if (!w || !h) throw new Error('Could not read image dimensions');

  const outDir = path.join(root, 'public', 'heroes');
  fs.mkdirSync(outDir, { recursive: true });

  if (flags.has('--8x2-top') || flags.has('--8x2-bottom')) {
    const useBottom = flags.has('--8x2-bottom');
    const pxCrop = parseNumFlag(argv, '--crop-bottom-px=');
    const pctCrop = parseNumFlag(argv, '--crop-bottom-pct=');
    const cropBottom =
      pxCrop != null && pxCrop >= 0
        ? Math.min(Math.round(pxCrop), h - 4)
        : Math.round(h * ((pctCrop != null ? pctCrop : 11) / 100));
    const hContent = h - cropBottom;
    if (hContent < 8) throw new Error('crop-bottom too large for image height');
    const rowH = Math.floor(hContent / 2);
    const cw = Math.floor(w / 8);
    const row = useBottom ? 1 : 0;
    const top = row * rowH;
    console.log(
      `Layout 8×2 (${useBottom ? 'bottom' : 'top'} row only), cropBottom=${cropBottom}px, cell ${cw}×${rowH}`,
    );
    for (let col = 0; col < 8; col++) {
      const file = HERO_ORDER[col];
      const left = col * cw;
      const cellPng = await sharp(arg).extract({ left, top, width: cw, height: rowH }).png().toBuffer();
      const out = await normalizeHeroPortrait(cellPng);
      const outPath = path.join(outDir, `${file}.png`);
      fs.writeFileSync(outPath, out);
      console.log(outPath);
    }
    console.log('Done. Run: npm run optimize-assets');
    return;
  }

  let layout;
  if (flags.has('--8x1')) layout = { cols: 8, rows: 1 };
  else if (flags.has('--4x2')) layout = { cols: 4, rows: 2 };
  else layout = detectLayout(w, h);

  const { cols, rows } = layout;
  const cw = Math.floor(w / cols);
  const ch = Math.floor(h / rows);
  const cells = buildCells(cols, rows);

  console.log(`Layout ${cols}×${rows}, cell ${cw}×${ch}`);

  for (const { file, col, row } of cells) {
    const left = col * cw;
    const top = row * ch;
    const cellPng = await sharp(arg).extract({ left, top, width: cw, height: ch }).png().toBuffer();
    const out = await normalizeHeroPortrait(cellPng);
    const outPath = path.join(outDir, `${file}.png`);
    fs.writeFileSync(outPath, out);
    console.log(outPath);
  }
  console.log('Done. Run: npm run optimize-assets');
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
