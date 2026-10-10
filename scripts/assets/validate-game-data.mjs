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
const primersSchema = readJson('data/schemas/primers.data.schema.json');
const traitsSchema = readJson('data/schemas/traits.data.schema.json');

const vHeroes = ajv.compile(heroesSchema);
const vEnemies = ajv.compile(enemiesSchema);
const vBattleModes = ajv.compile(battleModesSchema);
const vPrimers = ajv.compile(primersSchema);
const vTraits = ajv.compile(traitsSchema);

const heroes = readJson('data/raw/heroes.data.json');
const enemies = readJson('data/raw/enemies.data.json');
const battleModes = readJson('data/raw/battle-modes.json');
const primers = readJson('data/raw/primers.data.json');
const traits = readJson('data/raw/traits.data.json');

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
if (!vPrimers(primers)) {
  ok = false;
  console.error('primers.data.json:', ajv.errorsText(vPrimers.errors, { separator: '\n' }));
  console.error(vPrimers.errors);
}

if (!vTraits(traits)) {
  ok = false;
  console.error('traits.data.json:', ajv.errorsText(vTraits.errors, { separator: '\n' }));
  console.error(vTraits.errors);
}

// A field of an ability is set when it is true or above 0.
function fieldSet(ability, field) {
  const v = ability?.[field];
  return v === true || (typeof v === 'number' && v > 0);
}

// Trait requirements (G-64). A kit meets a requirement when ONE of its
// abilities has every `all` field set, at least one `any` field set (when the
// requirement lists any) and no `none` field set.
function kitMeets(requirement, kit) {
  return kit.some(
    (ability) =>
      (requirement.all || []).every((f) => fieldSet(ability, f)) &&
      (!requirement.any || requirement.any.some((f) => fieldSet(ability, f))) &&
      !(requirement.none || []).some((f) => fieldSet(ability, f)),
  );
}

// The requirements of `def` that `kit` does not meet.
function unmetNeeds(def, requirements, kit) {
  return (def?.needs || []).filter((need) => requirements[need] && !kitMeets(requirements[need], kit));
}

// Unit traits (G-62): every assignment names a defined trait and a real unit,
// every {key} in a trait's text is one of its own numbers (or {band}), and
// every trait defined is given to someone. Requirements (G-64): every `needs`
// entry is a defined requirement, every requirement field is a real ability
// field, and every unit's kit meets what its trait needs. Prestige traits
// (G-71): every hero evolution lists two different traits, its kit meets the
// needs of both, and every legacy Directive name maps to a second option.
function validateTraits(traits, heroes, enemies) {
  const errs = [];
  const defined = traits.traits || {};
  const requirements = traits.requirements || {};
  const used = new Set();
  const evolutionKits = new Map();
  const abilityFields = new Set();
  for (const h of heroes.heroes || []) {
    for (const a of h.abilities || []) Object.keys(a).forEach((k) => abilityFields.add(k));
    for (const e of h.evolutions || []) {
      evolutionKits.set(`${h.id}/${e.id}`, e.abilities || []);
      for (const a of e.abilities || []) Object.keys(a).forEach((k) => abilityFields.add(k));
    }
  }
  for (const kit of Object.values(enemies.enemyAbilities || {})) {
    for (const a of Object.values(kit || {})) Object.keys(a || {}).forEach((k) => abilityFields.add(k));
  }
  for (const [need, requirement] of Object.entries(requirements)) {
    for (const field of [...(requirement.all || []), ...(requirement.any || []), ...(requirement.none || [])]) {
      if (!abilityFields.has(field)) {
        errs.push(`traits.data.json: requirement '${need}' reads '${field}', which no ability has`);
      }
    }
  }
  const needsMet = (who, id, kit) => {
    for (const need of unmetNeeds(defined[id], requirements, kit)) {
      errs.push(`traits.data.json: ${who} carries '${id}' (${defined[id].name}), which needs '${need}', and its kit has none`);
    }
  };
  const secondOptions = new Set();
  for (const [key, ids] of Object.entries(traits.evolutions || {})) {
    if (!evolutionKits.has(key)) errs.push(`traits.data.json: evolutions '${key}' is not a hero evolution`);
    const options = Array.isArray(ids) ? ids : [ids];
    if (options.length !== 2 || options[0] === options[1]) {
      errs.push(`traits.data.json: evolutions '${key}' must list two different traits to choose between`);
    }
    for (const id of options) {
      if (!defined[id]) errs.push(`traits.data.json: evolutions '${key}' names an undefined trait '${id}'`);
      if (used.has(id)) errs.push(`traits.data.json: trait '${id}' is offered by more than one evolution`);
      needsMet(`evolutions '${key}'`, id, evolutionKits.get(key) || []);
      used.add(id);
    }
    if (options.length > 1) secondOptions.add(options[1]);
  }
  for (const key of evolutionKits.keys()) {
    if (!traits.evolutions?.[key]) errs.push(`traits.data.json: evolution '${key}' has no traits to choose between`);
  }
  for (const [directive, id] of Object.entries(traits.legacyDirectives || {})) {
    if (!secondOptions.has(id)) {
      errs.push(`traits.data.json: legacyDirectives '${directive}' maps to '${id}', which is not the second option of an evolution`);
    }
  }
  for (const [name, id] of Object.entries(traits.enemies || {})) {
    const unit = enemies.enemyUnitDefs?.[name];
    if (!unit) errs.push(`traits.data.json: enemies '${name}' is not an enemy unit`);
    if (!defined[id]) errs.push(`traits.data.json: enemies '${name}' names an undefined trait '${id}'`);
    needsMet(`enemies '${name}'`, id, Object.values(enemies.enemyAbilities?.[unit?.type] || {}));
    used.add(id);
  }
  for (const [id, def] of Object.entries(defined)) {
    if (!used.has(id)) errs.push(`traits.data.json: trait '${id}' is given to no unit`);
    for (const need of def.needs || []) {
      if (!requirements[need]) errs.push(`traits.data.json: trait '${id}' needs '${need}', which is not a defined requirement`);
    }
    for (const m of String(def.text || '').matchAll(/\{(\w+)\}/g)) {
      if (m[1] !== 'band' && typeof def[m[1]] !== 'number') {
        errs.push(`traits.data.json: trait '${id}' text uses {${m[1]}} but has no such number`);
      }
    }
  }
  return errs;
}
for (const err of validateTraits(traits, heroes, enemies)) {
  ok = false;
  console.error(err);
}

// The requirement rule must be able to fail (G-64). Each deliberate break is
// made on a copy of the real data and names the error it must raise; one the
// rule lets through fails this run.
function traitRequirementBreaks(traits, heroes, enemies) {
  const copy = (value) => JSON.parse(JSON.stringify(value));
  const breaks = {
    // A trait on a unit whose kit lacks what it needs.
    'Anchored on Pyro Specialist (no taunt)': ["needs 'taunt'", (t) => { t.evolutions['pulse/pyro'][0] = 'anchor'; }],
    // The second option is checked like the first.
    'Bristling as Pyro Specialist\'s second option (no spike)': ["needs 'spike'", (t) => { t.evolutions['pulse/pyro'][1] = 'counterweight'; }],
    'Shrouded on a kit where every ability deals damage': ["needs 'noDamage'", (t, h) => {
      for (const a of h.heroes.find((x) => x.id === 'engineer').evolutions.find((x) => x.id === 'phantom').abilities) a.dmg = a.dmg || 1;
    }],
    // A branch offers two traits, and a legacy Directive maps to a second option.
    'a branch with one trait to choose from': ['two different traits', (t) => { t.evolutions['pulse/arc'] = ['liveWire', 'liveWire']; }],
    'a legacy Directive mapped to a signature trait': ['not the second option', (t) => { t.legacyDirectives.Flashpoint = 'afterburn'; }],
    'Corrosive on Patrol Enforcer (no burn)': ["needs 'burn'", (t) => { t.enemies['Patrol Enforcer'] = 'corrosive'; }],
    // A kit that loses the ability its trait needs.
    'Pyro Specialist without detonate': ["needs 'detonate'", (t, h) => {
      for (const a of h.heroes.find((x) => x.id === 'pulse').evolutions.find((x) => x.id === 'pyro').abilities) delete a.detonate;
    }],
    'Oath Binder without a roll penalty': ["needs 'rollPenalty'", (t, h, e) => {
      for (const a of Object.values(e.enemyAbilities.voidBinder)) a.rfm = 0;
    }],
    // Both halves of a two-part need are checked on their own.
    'Phantom Engineer without jam': ["needs 'jam'", (t, h) => {
      for (const a of h.heroes.find((x) => x.id === 'engineer').evolutions.find((x) => x.id === 'phantom').abilities) {
        delete a.jam;
        delete a.jamAll;
      }
    }],
    // `all` must hold on ONE ability: an area attack is damage and blastAll together.
    'Blade Trooper whose area abilities deal no damage': ["needs 'areaAttack'", (t, h) => {
      for (const a of h.heroes.find((x) => x.id === 'combat').evolutions.find((x) => x.id === 'blade').abilities) {
        if (a.blastAll) a.dmg = 0;
      }
    }],
    // `none`: a single-target attack is damage without blastAll.
    'Shadow Operative with only area attacks': ["needs 'singleAttack'", (t, h) => {
      for (const a of h.heroes.find((x) => x.id === 'ghost').evolutions.find((x) => x.id === 'shadow').abilities) {
        if (a.dmg > 0) a.blastAll = true;
      }
    }],
    // The vocabulary itself.
    'a need that is not a defined requirement': ['not a defined requirement', (t) => { t.traits.barbed.needs = ['spikes']; }],
    'a requirement that reads a field no ability has': ['which no ability has', (t) => { t.requirements.detonate = { all: ['detonat'] }; }],
  };
  const missed = [];
  for (const [what, [expected, apply]] of Object.entries(breaks)) {
    const t = copy(traits);
    const h = copy(heroes);
    const e = copy(enemies);
    apply(t, h, e);
    if (!validateTraits(t, h, e).some((err) => err.includes(expected))) missed.push(what);
  }
  return missed;
}
if (ok) {
  for (const what of traitRequirementBreaks(traits, heroes, enemies)) {
    ok = false;
    console.error(`traits.data.json: the requirement rule let a deliberate break through: ${what}`);
  }
}

// Evolution ids: stable keys for portrait resolution
// (assets/portraits/<hero_id>_<evo_id>.png). Display callsigns may be renamed;
// preserve the stable ID and explicitly record those migrations (G-9).
const EVOLUTION_CALLSIGN_IDS = { OVERCLOCK: 'overclocked' };
function validateEvolutionIds(heroes) {
  const errs = [];
  const seen = new Set();
  for (const h of heroes.heroes || []) {
    for (const e of h.evolutions || []) {
      if (!e.id) continue; // presence enforced by the schema
      const expectedId = EVOLUTION_CALLSIGN_IDS[e.callsign] || e.callsign?.toLowerCase();
      if (e.callsign && e.id !== expectedId) {
        errs.push(`heroes.data.json: ${h.id} evolution '${e.name}' id '${e.id}' != stable id '${expectedId}'`);
      }
      if (seen.has(e.id)) errs.push(`heroes.data.json: duplicate evolution id '${e.id}'`);
      seen.add(e.id);
    }
  }
  return errs;
}
for (const err of validateEvolutionIds(heroes)) {
  ok = false;
  console.error(err);
}

// Primers: ids must be unique, and LOADED entries (not the $signal_hook_examples
// docs block) may not use the signal_hook type until a mechanic ships one.
function validatePrimerSemantics(primers) {
  const errs = [];
  const seen = new Set();
  for (const p of primers.primers || []) {
    if (seen.has(p.id)) errs.push(`primers.data.json: duplicate id '${p.id}'`);
    seen.add(p.id);
    if (p.trigger?.type === 'signal_hook') {
      errs.push(`primers.data.json: '${p.id}' uses signal_hook in the LOADED list — keep unshipped hooks in $signal_hook_examples`);
    }
  }
  return errs;
}
for (const err of validatePrimerSemantics(primers)) {
  ok = false;
  console.error(err);
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

// The summon flag and the summon ability go together (2026-10-10: False Image
// carried `summonElite` with no summon ability). The engine only summons for a
// unit that has both, so one without the other is a flag that says something
// the kit does not do.
function validateSummonFlags(enemies) {
  const errs = [];
  for (const [name, def] of Object.entries(enemies.enemyUnitDefs || {})) {
    const kit = Object.values(enemies.enemyAbilities?.[def.type] || {});
    const summons = kit.some((ab) => ab && ab.summonName && ab.summonChance > 0);
    if (def.summonElite && !summons) {
      errs.push(`enemyUnitDefs.${name}: summonElite is set but its kit '${def.type}' has no summon ability`);
    }
    if (summons && !def.summonElite) {
      errs.push(`enemyUnitDefs.${name}: its kit '${def.type}' has a summon ability but summonElite is not set, so it never fires`);
    }
  }
  return errs;
}

for (const err of validateSummonFlags(enemies)) {
  ok = false;
  console.error('enemies.data.json:', err);
}
{
  // The rule proves it can fail: False Image with its old flag back.
  const withFlag = JSON.parse(JSON.stringify(enemies));
  withFlag.enemyUnitDefs['False Image'].summonElite = true;
  if (!validateSummonFlags(withFlag).some((err) => err.includes('False Image'))) {
    ok = false;
    console.error('enemies.data.json: the summon flag rule let a deliberate break through (False Image with summonElite)');
  }
}

if (!ok) process.exit(1);
console.log('Game data JSON validates against schemas.');
