/**
 * Facility sim — which evolution paths show up on full clears most often.
 *
 * Usage: npx tsx scripts/debug/balance_sim_evo_fullclear.ts [iterations]
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import {
  type BattleProgressSimInput,
  formatEvoFullClearAudit,
  runEvoFullClearAudit,
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
const iterations = Math.max(1000, parseInt(process.argv[2] || '10000', 10) || 10000);

const input: BattleProgressSimInput = {
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

const result = runEvoFullClearAudit(input, iterations);
console.log(formatEvoFullClearAudit(result));

console.log('');
console.log('── Top evo paths to tune (highest FC presence) ──');
for (const row of result.rows.slice(0, 12)) {
  console.log(`  ★ ${row.baseHeroName} → ${row.evoPath} (${row.fullClearCount} full clears)`);
}
