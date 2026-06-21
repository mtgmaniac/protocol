/**
 * Facility anchor sim — base heroes + each evolution tested separately (day-1 evo kit).
 *
 * Usage: npx tsx scripts/debug/balance_sim_roster_audit.ts [iterations]
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import type { HeroDefinition } from '../sim/models/hero.interface';
import {
  type AnchoredFacilitySimResult,
  type BattleProgressSimInput,
  runAnchoredFacilitySim,
} from '../sim/battle-progress-sim.lib';

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
const heroesData = readJson('data/raw/heroes.data.json') as { heroes: HeroDefinition[] };

const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes[FACILITY_ID]!;
const FLAT_SCALE = Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 }));
const iterations = Math.max(1000, parseInt(process.argv[2] || '5000', 10) || 5000);

const baseInput: BattleProgressSimInput = {
  heroes: heroesData.heroes,
  unitDefs: enemiesData.enemyUnitDefs,
  suites: enemiesData.enemyAbilities,
  battleScale: FLAT_SCALE,
  modeOrder: [FACILITY_ID],
  battlesByMode: { [FACILITY_ID]: facility.battles },
  modeLabels: { [FACILITY_ID]: facility.label },
  trackHpScaleByMode: { [FACILITY_ID]: 1 },
  protocolRerolls: 10,
};

function groupEvoNames(hero: HeroDefinition): string[] {
  const names = new Set<string>();
  for (const evo of hero.evolutions ?? []) {
    if (evo.name) names.add(evo.name);
  }
  return [...names].sort();
}

function printTable(title: string, rows: AnchoredFacilitySimResult[], baseline?: number) {
  console.log(`\n── ${title} ──`);
  console.log('Unit                      Full clear   Mean wins   Δ vs baseline');
  console.log('──────────────────────────────────────────────────────────────');
  for (const row of rows) {
    const delta =
      baseline != null ? row.fullClearPct - baseline : 0;
    const sign = delta >= 0 ? '+' : '';
    const deltaStr = baseline != null ? `${sign}${delta.toFixed(1)}pp` : '—';
    console.log(
      `${row.label.padEnd(24)}  ${row.fullClearPct.toFixed(1).padStart(7)}%   ${row.meanWins.toFixed(2).padStart(7)}    ${deltaStr}`,
    );
  }
}

console.log(`Facility roster audit — ${iterations} runs each`);
console.log('Squad = anchored unit + 2 random partners. Base = tier 1 kit, random evo after fight 3.');
console.log('Evo rows = fight 1 on that evolution path (tier 2 HP + kit). Flat stats, 10 Protocol rerolls.');

const baseRows: AnchoredFacilitySimResult[] = [];
for (const hero of heroesData.heroes) {
  baseRows.push(
    runAnchoredFacilitySim(
      { ...baseInput, anchorHeroId: hero.id },
      iterations,
      hero.name,
      'base',
      null,
    ),
  );
}
baseRows.sort((a, b) => b.fullClearPct - a.fullClearPct);
const baseline = baseRows.reduce((s, r) => s + r.fullClearPct, 0) / baseRows.length;
const randomBaseline = runAnchoredFacilitySim(baseInput, iterations, 'Random 3-hero', 'base', null);

printTable('Starting units (base kit → random evo at fight 3)', baseRows, randomBaseline.fullClearPct);
console.log(`\nRandom 3-hero baseline: ${randomBaseline.fullClearPct.toFixed(1)}% full clear · ${randomBaseline.meanWins.toFixed(2)} mean wins`);

const evoRows: AnchoredFacilitySimResult[] = [];
for (const hero of heroesData.heroes) {
  for (const evoName of groupEvoNames(hero)) {
    evoRows.push(
      runAnchoredFacilitySim(
        {
          ...baseInput,
          anchorHeroId: hero.id,
          startAsEvoPath: evoName,
        },
        iterations,
        `${hero.name} → ${evoName}`,
        'evo',
        evoName,
      ),
    );
  }
}
evoRows.sort((a, b) => b.fullClearPct - a.fullClearPct);

printTable('Evolutions (day-1 evo kit, anchored)', evoRows, randomBaseline.fullClearPct);

console.log('\n── Per hero: base vs evo paths ──');
for (const hero of heroesData.heroes) {
  const base = baseRows.find(r => r.heroId === hero.id)!;
  const evos = evoRows.filter(r => r.heroId === hero.id).sort((a, b) => b.fullClearPct - a.fullClearPct);
  console.log(`\n${hero.name} (base ${base.fullClearPct.toFixed(1)}% FC · ${base.meanWins.toFixed(2)} wins)`);
  for (const e of evos) {
    const delta = e.fullClearPct - base.fullClearPct;
    const sign = delta >= 0 ? '+' : '';
    console.log(`  ${e.evoPath!.padEnd(22)} ${e.fullClearPct.toFixed(1).padStart(5)}% FC · ${e.meanWins.toFixed(2)} wins (${sign}${delta.toFixed(1)}pp vs base anchor)`);
  }
}
