/** Compact evo anchor FC% list. Usage: npx tsx scripts/debug/balance_sim_evo_only.ts [n] */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import type { HeroDefinition } from '../sim/models/hero.interface';
import { type BattleProgressSimInput, runAnchoredFacilitySim } from '../sim/battle-progress-sim.lib';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '../..');
const readJson = (rel: string) => JSON.parse(fs.readFileSync(path.join(ROOT, rel), 'utf8'));
const heroesData = readJson('data/raw/heroes.data.json') as { heroes: HeroDefinition[] };
const battleModes = readJson('data/raw/battle-modes.json');
const enemiesData = readJson('data/raw/enemies.data.json');
const n = parseInt(process.argv[2] || '6000', 10) || 6000;
const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes.facility;
const baseInput: BattleProgressSimInput = {
  heroes: heroesData.heroes,
  unitDefs: enemiesData.enemyUnitDefs,
  suites: enemiesData.enemyAbilities,
  battleScale: Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 })),
  modeOrder: [FACILITY_ID],
  battlesByMode: { [FACILITY_ID]: facility.battles },
  modeLabels: { [FACILITY_ID]: facility.label },
  trackHpScaleByMode: { [FACILITY_ID]: 1 },
  protocolRerolls: 10,
};
const evoNames = (h: HeroDefinition) => [...new Set((h.evolutions ?? []).map(e => e.name))];
const rows: { label: string; fc: number }[] = [];
for (const hero of heroesData.heroes) {
  for (const evo of evoNames(hero)) {
    const r = runAnchoredFacilitySim(
      { ...baseInput, anchorHeroId: hero.id, startAsEvoPath: evo },
      n,
      `${hero.name} → ${evo}`,
      'evo',
      evo,
    );
    rows.push({ label: r.label, fc: r.fullClearPct });
  }
}
rows.sort((a, b) => b.fc - a.fc);
for (const r of rows) {
  const flag = r.fc < 3 ? ' LOW' : r.fc > 7 ? ' HIGH' : '';
  console.log(`${r.fc.toFixed(1).padStart(5)}%  ${r.label}${flag}`);
}
