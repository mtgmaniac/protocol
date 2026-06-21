/**
 * CLI entry — uses bundled JSON (not localStorage). Keep logic in src/app/sim/battle-progress-sim.lib.ts
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../src/app/models/types';
import {
  type BattleProgressSimInput,
  formatBattleProgressSimResult,
  runBattleProgressSim,
} from '../src/app/sim/battle-progress-sim.lib';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

function readJson(rel: string) {
  return JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8')) as Record<string, unknown>;
}

const battleModes = readJson('src/app/data/json/battle-modes.json') as {
  order: string[];
  modes: Record<string, { label: string; battles: { enemies: { name: string }[] }[]; trackHpScale?: number }>;
};
const enemiesData = readJson('src/app/data/json/enemies.data.json') as {
  enemyUnitDefs: BattleProgressSimInput['unitDefs'];
  enemyAbilities: BattleProgressSimInput['suites'];
  battleEnemyScale: { hp: number; dmg: number }[];
};
const heroesData = readJson('src/app/data/json/heroes.data.json') as { heroes: BattleProgressSimInput['heroes'] };

const modeOrder = battleModes.order as BattleModeId[];
const battlesByMode = {} as BattleProgressSimInput['battlesByMode'];
const modeLabels = {} as BattleProgressSimInput['modeLabels'];
const trackHpScaleByMode = {} as Record<BattleModeId, number>;
for (const id of modeOrder) {
  const m = battleModes.modes[id];
  if (!m) continue;
  battlesByMode[id] = m.battles;
  modeLabels[id] = m.label;
  trackHpScaleByMode[id as BattleModeId] = m.trackHpScale ?? 1;
}

const input: BattleProgressSimInput = {
  heroes: heroesData.heroes,
  unitDefs: enemiesData.enemyUnitDefs,
  suites: enemiesData.enemyAbilities,
  battleScale: enemiesData.battleEnemyScale,
  modeOrder,
  battlesByMode,
  modeLabels,
  trackHpScaleByMode,
};

const iterations = Math.max(100, parseInt(process.argv[2] || '3000', 10) || 3000);
const result = runBattleProgressSim(input, iterations);
console.log(formatBattleProgressSimResult(result));
