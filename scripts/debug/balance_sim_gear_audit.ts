/**
 * Tier-1 gear audit — baseline facility full-clear vs every squad member wearing each gear piece.
 *
 * Usage: npx tsx scripts/debug/balance_sim_gear_audit.ts [iterations]
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import {
  type BattleProgressSimInput,
  runBattleProgressSim,
} from '../sim/battle-progress-sim.lib';
import { buildGearCatalog, type GearEntry } from '../sim/gear-sim.lib';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '../..');

function readJson(rel: string): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(path.join(ROOT, rel), 'utf8')) as Record<string, unknown>;
}

const battleModes = readJson('data/raw/battle-modes.json') as {
  modes: Record<string, { label: string; battles: { enemies: { name: string }[] }[] }>;
};
const enemiesData = readJson('data/raw/enemies.data.json') as {
  enemyUnitDefs: BattleProgressSimInput['unitDefs'];
  enemyAbilities: BattleProgressSimInput['suites'];
};
const heroesData = readJson('data/raw/heroes.data.json') as { heroes: BattleProgressSimInput['heroes'] };
const gearData = readJson('data/raw/gear.data.json') as { gear: GearEntry[] };

const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes[FACILITY_ID]!;
const FLAT_SCALE = Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 }));
const iterations = Math.max(500, parseInt(process.argv[2] || '3000', 10) || 3000);
const gearCatalog = buildGearCatalog(gearData);

function baseInput(): BattleProgressSimInput {
  return {
    heroes: heroesData.heroes,
    unitDefs: enemiesData.enemyUnitDefs,
    suites: enemiesData.enemyAbilities,
    battleScale: FLAT_SCALE,
    modeOrder: [FACILITY_ID],
    battlesByMode: { [FACILITY_ID]: facility.battles },
    modeLabels: { [FACILITY_ID]: facility.label },
    trackHpScaleByMode: { [FACILITY_ID]: 1 },
    protocolRerolls: 10,
    gearCatalog,
  };
}

function fullClearPct(input: BattleProgressSimInput): number {
  return runBattleProgressSim(input, iterations).tracks[0]!.fullClearPct;
}

console.log(`Tier-1 gear audit — facility track, ${iterations} random squads, all 3 heroes wear gear`);
console.log('Mode: flat enemyUnitDefs (matches Godot)\n');

const baseline = fullClearPct(baseInput());
console.log(`Baseline (no gear): ${baseline.toFixed(1)}% full clear\n`);

interface Row {
  id: string;
  name: string;
  rarity: string;
  fullClearPct: number;
  delta: number;
}

const rows: Row[] = [];
for (const entry of gearData.gear) {
  const pct = fullClearPct({ ...baseInput(), squadGearId: entry.id });
  rows.push({
    id: entry.id,
    name: entry.name,
    rarity: entry.rarity,
    fullClearPct: pct,
    delta: pct - baseline,
  });
}

rows.sort((a, b) => b.delta - a.delta);

console.log('Gear                      Rarity       Full clear   Δ vs baseline');
console.log('────────────────────────────────────────────────────────────────────');
for (const row of rows) {
  const sign = row.delta >= 0 ? '+' : '';
  console.log(
    `${row.name.padEnd(25)} ${row.rarity.padEnd(12)} ${row.fullClearPct.toFixed(1).padStart(7)}%   ${sign}${row.delta.toFixed(1)}pp`,
  );
}

console.log('\nOmitted in sim (Tier 1): battleStartCloak evasion, healShieldBonus on heals.');
console.log('Protocol on kill/start modeled; shared reroll budget only (no per-turn +1).');
