/**
 * Validates data/raw/*.json against data/schemas/*.json.
 *
 * Run from repo root:
 *   npm run validate-data
 *   node scripts/assets/validate-game-data.mjs
 */
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '../..');

const ajv = new Ajv({ allErrors: true, strict: false, validateSchema: false });
addFormats(ajv);

function readJson(rel) {
  return JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'));
}

const heroesSchema = readJson('data/schemas/heroes.data.schema.json');
const enemiesSchema = readJson('data/schemas/enemies.data.schema.json');
const battleModesSchema = readJson('data/schemas/battle-modes.schema.json');

const vHeroes = ajv.compile(heroesSchema);
const vEnemies = ajv.compile(enemiesSchema);
const vBattleModes = ajv.compile(battleModesSchema);

const heroes = readJson('data/raw/heroes.data.json');
const enemies = readJson('data/raw/enemies.data.json');
const battleModes = readJson('data/raw/battle-modes.json');

let ok = true;
if (!vBattleModes(battleModes)) {
  ok = false;
  console.error('battle-modes.json:', ajv.errorsText(vBattleModes.errors, { separator: '\n' }));
  console.error(vBattleModes.errors);
}
if (!vHeroes(heroes)) {
  ok = false;
  console.error('heroes.data.json:', ajv.errorsText(vHeroes.errors, { separator: '\n' }));
  console.error(vHeroes.errors);
}
if (!vEnemies(enemies)) {
  ok = false;
  console.error('enemies.data.json:', ajv.errorsText(vEnemies.errors, { separator: '\n' }));
  console.error(vEnemies.errors);
}

function validateEnemyAbilitySemantics(enemies) {
  const suites = enemies.enemyAbilities;
  if (!suites || typeof suites !== 'object') return null;
  for (const [type, suite] of Object.entries(suites)) {
    if (!suite || typeof suite !== 'object') continue;
    for (const [z, ab] of Object.entries(suite)) {
      if (!ab || typeof ab !== 'object') continue;
      const burn = (ab.burn || 0) > 0;
      const ls = (ab.lifestealPct || 0) > 0;
      if (burn && ls) {
        return `enemyAbilities.${type}.${z}: burn and lifestealPct cannot both be set`;
      }
    }
  }
  return null;
}

const sem = validateEnemyAbilitySemantics(enemies);
if (sem) {
  ok = false;
  console.error('enemies.data.json:', sem);
}

function validateBattleSpawnNames(bm, unitDefs) {
  const missing = new Set();
  for (const id of bm.order || []) {
    const mode = bm.modes?.[id];
    if (!mode?.battles) continue;
    for (const sp of mode.battles) {
      for (const e of sp.enemies || []) {
        const n = e.name;
        if (n && !unitDefs[n]) missing.add(n);
      }
    }
  }
  if (missing.size) {
    return `Unknown enemy unit name(s) in battle-modes.json: ${[...missing].sort().join(', ')}`;
  }
  return null;
}

const bmSem = validateBattleSpawnNames(battleModes, enemies.enemyUnitDefs || {});
if (bmSem) {
  ok = false;
  console.error('battle-modes.json:', bmSem);
}

// fix-1.1: every summon reference must resolve to a real unit def, and the
// target must be ai:"dumb" — battle_scene refuses to inject non-dumb summons,
// so anything else is a silent no-op at runtime.
function validateSummonRefs(enemies) {
  const defs = enemies.enemyUnitDefs || {};
  const errs = [];
  for (const [type, suite] of Object.entries(enemies.enemyAbilities || {})) {
    if (!suite || typeof suite !== 'object') continue;
    for (const [z, ab] of Object.entries(suite)) {
      if (!ab || typeof ab !== 'object') continue;
      if (ab.summonName === undefined && ab.summonChance === undefined) continue;
      if (!ab.summonName || !(ab.summonChance > 0)) {
        errs.push(`enemyAbilities.${type}.${z}: summonName and summonChance must be set together`);
        continue;
      }
      const def = defs[ab.summonName];
      if (!def) {
        errs.push(`enemyAbilities.${type}.${z}: summonName '${ab.summonName}' does not resolve to an enemyUnitDefs entry`);
      } else if (def.ai !== 'dumb') {
        errs.push(`enemyAbilities.${type}.${z}: summon target '${ab.summonName}' must be ai:"dumb" (battle blocks non-dumb summons)`);
      }
    }
  }
  return errs;
}

for (const err of validateSummonRefs(enemies)) {
  ok = false;
  console.error('enemies.data.json:', err);
}

if (!ok) process.exit(1);
console.log('Game data JSON validates against schemas.');
