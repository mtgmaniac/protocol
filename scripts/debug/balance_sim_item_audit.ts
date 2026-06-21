/**
 * Gear + consumable audit — baseline facility full-clear vs each item in isolation.
 *
 * Gear: all 3 squad members wear the piece for the whole track.
 * Consumables: 1 copy granted at the start of each battle (heuristic use timing).
 *
 * Usage: npx tsx scripts/debug/balance_sim_item_audit.ts [iterations] [--gear-only|--consumables-only]
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
import { buildItemCatalog, type ItemEntry, SKIPPED_CONSUMABLE_TYPES } from '../sim/consumable-sim.lib';

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
const itemsData = readJson('data/raw/items.data.json') as { items: ItemEntry[] };

const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes[FACILITY_ID]!;
const FLAT_SCALE = Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 }));
const args = process.argv.slice(2);
const gearOnly = args.includes('--gear-only');
const consumablesOnly = args.includes('--consumables-only');
const iterArg = args.find(a => !a.startsWith('--'));
const iterations = Math.max(500, parseInt(iterArg || '3000', 10) || 3000);
const gearCatalog = buildGearCatalog(gearData);
const itemCatalog = buildItemCatalog(itemsData);

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
    itemCatalog,
  };
}

function fullClearPct(input: BattleProgressSimInput): number {
  return runBattleProgressSim(input, iterations).tracks[0]!.fullClearPct;
}

interface Row {
  id: string;
  name: string;
  rarity: string;
  fullClearPct: number;
  delta: number;
}

function printTable(title: string, rows: Row[], baseline: number) {
  console.log(`\n── ${title} ──`);
  console.log(`Baseline: ${baseline.toFixed(1)}% full clear (${iterations} runs)\n`);
  console.log('Name                      Rarity       Full clear   Δ vs baseline');
  console.log('────────────────────────────────────────────────────────────────────');
  for (const row of rows) {
    const sign = row.delta >= 0 ? '+' : '';
    console.log(
      `${row.name.padEnd(25)} ${row.rarity.padEnd(12)} ${row.fullClearPct.toFixed(1).padStart(7)}%   ${sign}${row.delta.toFixed(1)}pp`,
    );
  }
}

console.log(`Item audit — facility track, ${iterations} random squads`);
console.log('Mode: flat enemyUnitDefs (matches Godot)\n');

const baseline = fullClearPct(baseInput());

if (!consumablesOnly) {
  const gearRows: Row[] = gearData.gear.map(entry => {
    const pct = fullClearPct({ ...baseInput(), squadGearId: entry.id });
    return {
      id: entry.id,
      name: entry.name,
      rarity: entry.rarity,
      fullClearPct: pct,
      delta: pct - baseline,
    };
  });
  gearRows.sort((a, b) => b.delta - a.delta);
  printTable('Gear (all 3 heroes wear piece)', gearRows, baseline);
}

if (!gearOnly) {
  const consumableRows: Row[] = [];
  for (const entry of itemsData.items) {
    if (SKIPPED_CONSUMABLE_TYPES.has(entry.effect.type)) {
      consumableRows.push({
        id: entry.id,
        name: entry.name,
        rarity: entry.rarity,
        fullClearPct: baseline,
        delta: 0,
      });
      continue;
    }
    const pct = fullClearPct({ ...baseInput(), trackConsumableId: entry.id });
    consumableRows.push({
      id: entry.id,
      name: entry.name,
      rarity: entry.rarity,
      fullClearPct: pct,
      delta: pct - baseline,
    });
  }
  consumableRows.sort((a, b) => b.delta - a.delta);
  printTable('Consumables (1× per battle, heuristic use)', consumableRows, baseline);
}

console.log('\nSim omissions: cloak/reroll consumables, healShieldBonus gear, relics.');
console.log('Items cost 1 Protocol from the shared reroll budget; gainProtocol adds back amount.');
