/**
 * Task 5 — Monte Carlo balance pass for the facility operation.
 * Uses live data/raw JSON + legacy battle-progress-sim combat model.
 *
 * Usage (from repo root):
 *   npx tsx scripts/debug/balance_sim_facility.ts [iterations] [--scaled]
 *
 * Default: flat stats (matches Godot — same enemyUnitDefs every fight).
 * --scaled: legacy per-fight battleEnemyScale + trackHpScale (sim tuning lab only).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import {
  type BattleProgressSimInput,
  formatBattleProgressSimResult,
  runBattleProgressSim,
} from '../sim/battle-progress-sim.lib';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '../..');

function readJson(rel: string): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(path.join(ROOT, rel), 'utf8')) as Record<string, unknown>;
}

const battleModes = readJson('data/raw/battle-modes.json') as {
  order: string[];
  modes: Record<string, { label: string; battles: { enemies: { name: string }[] }[]; trackHpScale?: number }>;
};
const enemiesData = readJson('data/raw/enemies.data.json') as {
  enemyUnitDefs: BattleProgressSimInput['unitDefs'];
  enemyAbilities: BattleProgressSimInput['suites'];
  battleEnemyScale: { hp: number; dmg: number }[];
};
const heroesData = readJson('data/raw/heroes.data.json') as { heroes: BattleProgressSimInput['heroes'] };

const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes[FACILITY_ID];
if (!facility) {
  throw new Error('facility mode missing from battle-modes.json');
}

const FLAT_SCALE = Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 }));
const args = process.argv.slice(2);
const useScaled = args.includes('--scaled');
const iterArg = args.find(a => a !== '--scaled');
const iterations = Math.max(200, parseInt(iterArg || '3000', 10) || 3000);

const input: BattleProgressSimInput = {
  heroes: heroesData.heroes,
  unitDefs: enemiesData.enemyUnitDefs,
  suites: enemiesData.enemyAbilities,
  battleScale: useScaled ? enemiesData.battleEnemyScale : FLAT_SCALE,
  modeOrder: [FACILITY_ID],
  battlesByMode: { [FACILITY_ID]: facility.battles },
  modeLabels: { [FACILITY_ID]: facility.label },
  trackHpScaleByMode: { [FACILITY_ID]: useScaled ? (facility.trackHpScale ?? 1) : 1 },
  protocolRerolls: 10,
};

const result = runBattleProgressSim(input, iterations);
const track = result.tracks[0]!;

console.log(
  useScaled
    ? 'Mode: scaled (battleEnemyScale + trackHpScale — sim tuning lab)'
    : 'Mode: flat (enemyUnitDefs only — matches Godot)',
);
console.log(formatBattleProgressSimResult(result));

const avgTurnsToClear = track.reachBattlePct.map((reach, i) => {
  const cond = track.conditionalWinPct[i] ?? 0;
  const hp = track.avgSurvivorHpPct[i];
  return { fight: i + 1, reach, cond, hp, enemies: facility.battles[i]?.enemies.map(e => e.name).join(', ') };
});

console.log('── Task 5 cliff scan (facility) ──');
console.log('  Flag: conditional win < 55% OR avg post-win HP < 45% OR >12pp drop vs prior fight.');
let priorCond = 100;
for (const row of avgTurnsToClear) {
  const cliff =
    row.cond < 55 ||
    (row.hp != null && row.hp < 45) ||
    priorCond - row.cond > 12;
  const mark = cliff ? ' ⚠ CLIFF' : '';
  const hpStr = row.hp != null ? `${row.hp.toFixed(1)}%` : 'n/a';
  console.log(
    `  Fight ${row.fight}: reach ${row.reach.toFixed(1)}% · win ${row.cond.toFixed(1)}% · HP ${hpStr} · ${row.enemies}${mark}`,
  );
  priorCond = row.cond;
}

// E[fights won] = Σ P(reach fight k) × P(win | reached k)
const meanWins =
  track.reachBattlePct.reduce(
    (sum, reach, i) => sum + (reach / 100) * ((track.conditionalWinPct[i] ?? 0) / 100),
    0,
  );
console.log('');
console.log(`  Full clear rate: ${track.fullClearPct.toFixed(1)}% (${iterations} random 3-hero squads)`);
console.log(`  Mean fights won: ${meanWins.toFixed(2)} / ${facility.battles.length}`);
console.log('  Note: evolution triggers after winning fight 3 — fight 3 is pre-evo vs Patrol Elite.');
console.log('');
console.log('── Suggested data-only tweaks (NOT applied) ──');
console.log('  Review only — tune if full clear is far from 25–45% for a competent first-time player.');
if (track.fullClearPct > 55) {
  console.log('  • Full clear high: bump enemy HP/dmg in enemyUnitDefs or add harder encounter comps.');
} else if (track.fullClearPct < 18) {
  console.log('  • Full clear low: trim enemyUnitDefs HP/dmg or soften fight 3/5 roster.');
}
for (const row of avgTurnsToClear) {
  if (row.cond < 50) {
    console.log(`  • Fight ${row.fight} (${row.enemies}): win ${row.cond.toFixed(1)}% — adjust unit defs or composition.`);
  }
}
if (track.conditionalWinPct[2] != null && track.conditionalWinPct[2]! < 35) {
  console.log('  • Fight 3 cliff (pre-evolution): soften Patrol Elite in enemyUnitDefs or swap roster.');
}
if (track.conditionalWinPct[4] != null && track.conditionalWinPct[4]! < 50) {
  console.log('  • Fight 5 spike: trim Guard Elite HP/dmg or drop to one Guard.');
}
