/**
 * Per-hero facility win rates — each hero anchored in every squad (+ 2 random partners).
 *
 * Usage: npx tsx scripts/debug/balance_sim_per_hero.ts [iterations]
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import {
  type BattleProgressSimInput,
  runBattleProgressSim,
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
const heroesData = readJson('data/raw/heroes.data.json') as { heroes: BattleProgressSimInput['heroes'] };

const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes[FACILITY_ID]!;
const FLAT_SCALE = Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 }));
const iterations = Math.max(500, parseInt(process.argv[2] || '5000', 10) || 5000);

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

console.log(`Per-hero facility sim — ${iterations} runs each (flat stats, evo + 10 Protocol rerolls)`);
console.log('Squad = anchored hero + 2 random partners from the other seven.\n');

interface Row {
  id: string;
  name: string;
  fullClearPct: number;
  meanWins: number;
}

const rows: Row[] = [];

for (const hero of heroesData.heroes) {
  const result = runBattleProgressSim({ ...baseInput, anchorHeroId: hero.id }, iterations);
  const track = result.tracks[0]!;
  const meanWins = track.reachBattlePct.reduce(
    (sum, reach, i) => sum + (reach / 100) * ((track.conditionalWinPct[i] ?? 0) / 100),
    0,
  );
  rows.push({
    id: hero.id,
    name: hero.name,
    fullClearPct: track.fullClearPct,
    meanWins,
  });
}

rows.sort((a, b) => b.fullClearPct - a.fullClearPct);

const baseline = runBattleProgressSim(baseInput, iterations);
const baseTrack = baseline.tracks[0]!;
const baseMeanWins = baseTrack.reachBattlePct.reduce(
  (sum, reach, i) => sum + (reach / 100) * ((baseTrack.conditionalWinPct[i] ?? 0) / 100),
  0,
);

console.log(`Random 3-hero baseline: ${baseTrack.fullClearPct.toFixed(1)}% full clear · ${baseMeanWins.toFixed(2)} mean wins\n`);
console.log('Hero                  Full clear   Mean wins   Δ vs baseline');
console.log('─────────────────────────────────────────────────────────────');

for (const row of rows) {
  const delta = row.fullClearPct - baseTrack.fullClearPct;
  const sign = delta >= 0 ? '+' : '';
  console.log(
    `${row.name.padEnd(20)}  ${row.fullClearPct.toFixed(1).padStart(7)}%   ${row.meanWins.toFixed(2).padStart(7)}    ${sign}${delta.toFixed(1)}pp`,
  );
}
