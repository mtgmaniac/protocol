/**
 * Diagnose Pulse vs Strike anchor gap — evolution cliff, fight reach, effective DPS.
 * Usage: npx tsx scripts/debug/diagnose_pulse_anchor.ts [iterations]
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { BattleModeId } from '../sim/models/types';
import type { HeroAbility } from '../sim/models/ability.interface';
import { normalizeHeroAbility } from '../sim/hero-ability-normalize';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '../..');

function readJson(rel: string): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(path.join(ROOT, rel), 'utf8')) as Record<string, unknown>;
}

const heroesData = readJson('data/raw/heroes.data.json') as {
  heroes: { id: string; name: string; hp: number; abilities: HeroAbility[]; evolutions: unknown[] }[];
  heroZones: Record<string, [number, number, string][]>;
};

function zoneWeights(heroId: string): Map<string, number> {
  const zones = heroesData.heroZones[heroId] ?? [];
  const out = new Map<string, number>();
  for (const [lo, hi] of zones) {
    const z = zones.find(([, , name]) => name === zones.find(([l, h]) => l === lo && h === hi)?.[2]);
  }
  // simpler: use ability ranges directly
  return out;
}

function expectedDmgPerRoll(abilities: HeroAbility[], enemyCount: number): number {
  let total = 0;
  for (let roll = 1; roll <= 20; roll++) {
    const ab = abilities.find(a => roll >= a.range[0] && roll <= a.range[1]);
    if (!ab) continue;
    const n = ab.blastAll ? enemyCount : 1;
    let dmg = (ab.dmg || 0) * n;
    // burn: approx total = burn * burnT per target (ignores overkill / early death)
    if ((ab.burn || 0) > 0) {
      const turns = ab.burnT || 2;
      dmg += (ab.burn || 0) * turns * (ab.blastAll ? enemyCount : 1);
    }
    total += dmg;
  }
  return total / 20;
}

function groupEvoPaths(evolutions: { name: string; focus: string; hp: number; abilities: HeroAbility[] }[]) {
  const map = new Map<string, { name: string; hp: number; abilities: HeroAbility[] }>();
  for (const evo of evolutions) {
    if (!map.has(evo.name)) {
      map.set(evo.name, { name: evo.name, hp: evo.hp, abilities: evo.abilities.map(normalizeHeroAbility) });
    } else {
      const ex = map.get(evo.name)!;
      ex.abilities.push(...evo.abilities.map(normalizeHeroAbility));
      if (evo.hp > 0) ex.hp = evo.hp;
    }
  }
  return Array.from(map.values());
}

const pulse = heroesData.heroes.find(h => h.id === 'pulse')!;
const combat = heroesData.heroes.find(h => h.id === 'combat')!;
const pulseBase = pulse.abilities.map(normalizeHeroAbility);
const combatBase = combat.abilities.map(normalizeHeroAbility);
const pulseEvos = groupEvoPaths(pulse.evolutions as { name: string; focus: string; hp: number; abilities: HeroAbility[] }[]);
const combatEvos = groupEvoPaths(combat.evolutions as { name: string; focus: string; hp: number; abilities: HeroAbility[] }[]);

console.log('=== Expected damage per hero turn (by enemy count on field) ===\n');
for (const n of [1, 2, 3]) {
  console.log(`--- ${n} living enemies ---`);
  console.log(`  Pulse base:   ${expectedDmgPerRoll(pulseBase, n).toFixed(1)}`);
  for (const p of pulseEvos) {
    console.log(`  Pulse ${p.name} (HP ${p.hp}): ${expectedDmgPerRoll(p.abilities, n).toFixed(1)}`);
  }
  console.log(`  Strike base:  ${expectedDmgPerRoll(combatBase, n).toFixed(1)}`);
  for (const p of combatEvos) {
    console.log(`  Strike ${p.name} (HP ${p.hp}): ${expectedDmgPerRoll(p.abilities, n).toFixed(1)}`);
  }
  console.log('');
}

console.log('=== Zone roll odds (d20) ===');
function printZoneOdds(heroId: string, abilities: HeroAbility[]) {
  console.log(`  ${heroId}:`);
  for (const ab of abilities) {
    const pct = ((ab.range[1] - ab.range[0] + 1) / 20 * 100).toFixed(0);
    const dmgNote = (ab.dmg || 0) > 0 || (ab.burn || 0) > 0 ? `${ab.dmg || 0} dmg${ab.blastAll ? '×all' : ''}${ab.burn ? `+${ab.burn}burn` : ''}` : ab.eff;
    console.log(`    d${ab.range[0]}-${ab.range[1]} (${pct}%): ${ab.name} — ${dmgNote}`);
  }
}
printZoneOdds('pulse base', pulseBase);
console.log('');
printZoneOdds('cryo evo', pulseEvos.find(p => p.name === 'Cryo Specialist')!.abilities);
console.log('');

// Run anchored sim with fight-by-fight conditional win for pulse vs combat
import {
  type BattleProgressSimInput,
  runBattleProgressSim,
} from '../sim/battle-progress-sim.lib';

const battleModes = readJson('data/raw/battle-modes.json') as {
  modes: Record<string, { label: string; battles: { enemies: { name: string }[] }[] }>;
};
const enemiesData = readJson('data/raw/enemies.data.json') as {
  enemyUnitDefs: BattleProgressSimInput['unitDefs'];
  enemyAbilities: BattleProgressSimInput['suites'];
};
const FACILITY_ID = 'facility' as BattleModeId;
const facility = battleModes.modes[FACILITY_ID]!;
const FLAT_SCALE = Array.from({ length: 10 }, () => ({ hp: 1, dmg: 1 }));
const iterations = Math.max(1000, parseInt(process.argv[2] || '6000', 10) || 6000);

const baseInput: BattleProgressSimInput = {
  heroes: heroesData.heroes as BattleProgressSimInput['heroes'],
  unitDefs: enemiesData.enemyUnitDefs,
  suites: enemiesData.enemyAbilities,
  battleScale: FLAT_SCALE,
  modeOrder: [FACILITY_ID],
  battlesByMode: { [FACILITY_ID]: facility.battles },
  modeLabels: { [FACILITY_ID]: facility.label },
  trackHpScaleByMode: { [FACILITY_ID]: 1 },
  protocolRerolls: 10,
};

console.log(`=== Anchored sim (${iterations} runs) — conditional win % by fight ===\n`);
for (const anchorId of ['pulse', 'combat'] as const) {
  const r = runBattleProgressSim({ ...baseInput, anchorHeroId: anchorId }, iterations);
  const t = r.tracks[0]!;
  const hero = heroesData.heroes.find(h => h.id === anchorId)!;
  console.log(`${hero.name} anchored — full clear ${t.fullClearPct.toFixed(1)}%`);
  for (let i = 0; i < facility.battles.length; i++) {
    const reach = t.reachBattlePct[i] ?? 0;
    const win = t.conditionalWinPct[i] ?? 0;
    const enemies = facility.battles[i]!.enemies.map(e => e.name).join(', ');
    const evoMark = i === 2 ? ' ← evo after win' : i >= 3 ? ' (post-evo)' : '';
    console.log(`  Fight ${i + 1}: reach ${reach.toFixed(1)}% · win ${win.toFixed(1)}% · ${enemies}${evoMark}`);
  }
  console.log('');
}
