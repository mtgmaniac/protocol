/**
 * Monte Carlo battle progress sim (shared by dev DATA panel + CLI).
 * Random 3-hero squads; simplified combat vs bundled encounter tables + live data input.
 */
import type { EnemyAbility, EnemyAbilitySuite, HeroAbility } from '../models/ability.interface';
import type { EnemyDefinition } from '../models/enemy.interface';
import type { EvolutionTier, HeroDefinition } from '../models/hero.interface';
import type { BattleModeId, Zone } from '../models/types';
import { normalizeHeroAbility } from '../data/hero-ability-normalize';
import {
  addShieldToUnit,
  absorbDamageThroughShield,
  coalesceShieldStacks,
  tickUnitShield,
  type ShieldStack,
} from '../utils/shield-stack.util';

const ENEMY_ZONES: [number, number, Zone][] = [
  [1, 4, 'recharge'],
  [5, 10, 'strike'],
  [11, 16, 'surge'],
  [17, 19, 'crit'],
  [20, 20, 'overload'],
];

const EMPTY_ENEMY_AB: EnemyAbility = {
  name: '?',
  eff: '—',
  dmg: 0,
  dot: 0,
  dT: 0,
  heal: 0,
  rfe: 0,
  shield: 0,
};

const DEFAULT_DOT_TURNS = 2;

export interface BattleProgressSimInput {
  heroes: HeroDefinition[];
  unitDefs: Record<string, Omit<EnemyDefinition, 'name'>>;
  suites: Record<string, EnemyAbilitySuite>;
  battleScale: { hp: number; dmg: number }[];
  modeOrder: BattleModeId[];
  /** encounter tables per mode */
  battlesByMode: Record<BattleModeId, { enemies: { name: string }[] }[]>;
  modeLabels: Record<BattleModeId, string>;
  /** Per-operation enemy max HP multiplier after battle index scale (matches game `trackHpScale`). */
  trackHpScaleByMode: Record<BattleModeId, number>;
  /**
   * Protocol reroll budget for the entire track (shared across all heroes and all battles).
   * When a hero rolls ≤4 (recharge zone) and budget remains, they reroll once and keep the higher result.
   * 0 = no Protocol modeled (default).
   */
  protocolRerolls: number;
}

/** Battles 1..N “reach” ladder (here N=10). */
export const REACH_BATTLE_COUNT = 10;

/** Fair % of runs that include a given hero (3 of 8 picked). */
export const EXPECTED_HERO_RUN_INCLUSION_PCT = (3 / 8) * 100;

export interface BattleProgressSimHeroRep {
  heroId: string;
  /** % of all simulated runs (all modes × iterations) this hero was in the squad */
  pctOfRuns: number;
  /** vs EXPECTED_HERO_RUN_INCLUSION_PCT */
  deltaVsFairRunsPct: number;
  /** Among runs that full-cleared a track: % of those runs that included hero (fair = same 37.5%) */
  pctOfFullClearRuns: number | null;
  deltaVsFairFullClearPct: number | null;
  /** fullClearAppearances / expected appearances; null if no full clears */
  representationIndexFullClear: number | null;
}

/** One unordered 3-hero squad’s aggregate stats (across all operations in this sim batch). */
export interface BattleProgressSimTrioStats {
  heroIds: [string, string, string];
  runs: number;
  fullClears: number;
  /** fullClears / runs × 100 */
  fullClearPct: number;
  /** Mean fights won per run (for that op’s track length, capped by wipe). */
  meanWins: number;
}

export interface BattleProgressSimResult {
  iterations: number;
  reachBattleCount: number;
  protocolRerolls: number;
  tracks: {
    modeId: BattleModeId;
    label: string;
    battlesInTrack: number;
    /** Cumulative: % of runs that reached (and attempted) battle N. Index 0 = battle 1. */
    reachBattlePct: number[];
    /**
     * Conditional: given a squad reached battle N, % that won it.
     * Index 0 = battle 1 (always reached, so = win rate of first fight).
     */
    conditionalWinPct: number[];
    /**
     * Average HP% of surviving heroes immediately after winning each battle.
     * Index 0 = battle 1. null when no wins recorded for that battle.
     */
    avgSurvivorHpPct: (number | null)[];
    /** Won every fight in this track */
    fullClearPct: number;
  }[];
  heroRepresentation: {
    totalRuns: number;
    fullClearsAllModes: number;
    byHero: BattleProgressSimHeroRep[];
  };
  /**
   * Empirical trio performance: each run = one random squad on one operation.
   * Not causal synergy — correlation under this sim only (no items, Protocol, etc.).
   */
  trioStats: {
    minRunsForRanked: number;
    /** Best mean depth (wins) before wipe */
    topByMeanWins: BattleProgressSimTrioStats[];
    /** Best full-clear rate on the track they rolled */
    topByFullClearPct: BattleProgressSimTrioStats[];
    /** All observed trios with ≥1 run (up to 56 rows), sorted by mean wins */
    allTrios: BattleProgressSimTrioStats[];
  };
}

interface SimHero {
  id: string;
  name: string;
  maxHp: number;
  hp: number;
  shield: number;
  shT: number;
  shieldStacks: ShieldStack[];
  def: HeroDefinition;
  tier: 1 | 2;
  /** Cumulative effective d20s (tier 1 only), matches game XP input */
  bRolls: number[];
  xp: number;
  /** Base or post-evolution kit */
  activeAbilities: HeroAbility[];
  dot: number;
  dT: number;
}

interface SimEnemy {
  name: string;
  type: string;
  ai: string;
  hp: number;
  maxHp: number;
  shield: number;
  shT: number;
  shieldStacks: ShieldStack[];
  p2: boolean;
  pThr: number | null;
  dmgScale: number;
  dot: number;
  dT: number;
  dieFreezeRollsRemaining: number;
}

function d20(): number {
  return Math.floor(Math.random() * 20) + 1;
}

function randInt(a: number, b: number): number {
  return Math.floor(Math.random() * (b - a + 1)) + a;
}

function enemyZoneFromRoll(r: number): Zone {
  const x = Math.min(20, Math.max(1, r));
  for (const [lo, hi, z] of ENEMY_ZONES) {
    if (x >= lo && x <= hi) return z;
  }
  return 'overload';
}

function pickAbilityForRoll(abilities: HeroAbility[], roll: number): HeroAbility | null {
  const r = Math.min(20, roll);
  return abilities.find(a => r >= a.range[0] && r <= a.range[1]) ?? null;
}

/** Same grouping as {@link EvolutionService.groupEvoPaths} */
function groupEvoPaths(evolutions: EvolutionTier[]) {
  const map = new Map<string, { name: string; focus: string; hp: number; abilities: HeroAbility[] }>();
  for (const evo of evolutions) {
    if (!map.has(evo.name)) {
      map.set(evo.name, {
        name: evo.name,
        focus: evo.focus,
        hp: evo.hp,
        abilities: evo.abilities.map(normalizeHeroAbility),
      });
    } else {
      const existing = map.get(evo.name)!;
      existing.abilities.push(...evo.abilities.map(normalizeHeroAbility));
      if (evo.hp > 0) existing.hp = evo.hp;
      if (evo.focus) existing.focus = evo.focus;
    }
  }
  return Array.from(map.values());
}

/** Mirrors {@link EvolutionService.calculateHrs} — uses full cumulative bRolls */
function calculateHrsFromRolls(bRolls: number[]): number {
  if (bRolls.length === 0) return 0;
  const avg = bRolls.reduce((a, b) => a + b, 0) / bRolls.length;
  let pts: number;
  if (avg >= 20) pts = 10;
  else if (avg >= 17) pts = 7;
  else if (avg >= 13) pts = 5;
  else if (avg >= 6) pts = 3;
  else pts = 1;
  return Math.round(pts * 1.5);
}

function awardXpAfterWin(heroes: SimHero[]): void {
  for (const h of heroes) {
    if (h.hp <= 0 || h.tier !== 1) continue;
    h.xp += calculateHrsFromRolls(h.bRolls);
  }
}

/**
 * After winning battle index `completedBattleIndex` (0-based), eligible tier-1 heroes with xp≥18 evolve.
 * Matches game: evolution offered once `battle >= 2` (third fight won).
 */
function tryEvolveSquad(heroes: SimHero[], completedBattleIndex: number): void {
  if (completedBattleIndex < 2) return;
  const evos = heroes.filter(h => h.hp > 0 && h.tier === 1 && h.xp >= 18);
  for (const h of evos) {
    const paths = groupEvoPaths(h.def.evolutions ?? []);
    if (paths.length === 0) continue;
    const path = paths[Math.floor(Math.random() * paths.length)]!;
    const ratio = h.hp / Math.max(1, h.maxHp);
    h.activeAbilities = path.abilities.map(normalizeHeroAbility);
    h.name = path.name;
    h.maxHp = path.hp;
    h.hp = Math.max(1, Math.round(path.hp * ratio));
    h.tier = 2;
    h.xp = 0;
    h.bRolls = [];
  }
}

function sampleHeroDamage(ab: ReturnType<typeof pickAbilityForRoll>): number {
  if (!ab) return 0;
  const lo = ab.dMin ?? ab.dmg;
  const hi = ab.dMax ?? ab.dmg;
  if (lo != null && hi != null && hi !== lo) return randInt(Math.min(lo, hi), Math.max(lo, hi));
  return ab.dmg || 0;
}

function scaleEnemyDef(
  raw: Omit<EnemyDefinition, 'name'> & { name: string },
  battleIndex: number,
  battleScale: { hp: number; dmg: number }[],
  trackHpScale: number,
): SimEnemy {
  const idx = Math.max(0, Math.min(battleScale.length - 1, battleIndex));
  const sc = battleScale[idx] || { hp: 1, dmg: 1 };
  const hpM = sc.hp * trackHpScale;
  const dmgM = sc.dmg;
  return {
    name: raw.name,
    type: raw.type,
    ai: raw.ai,
    hp: Math.max(1, Math.round(raw.hp * hpM)),
    maxHp: Math.max(1, Math.round(raw.hp * hpM)),
    shield: 0,
    shT: 0,
    shieldStacks: [],
    p2: false,
    pThr: raw.pThr != null ? Math.max(1, Math.round(raw.pThr * hpM)) : null,
    dmgScale: dmgM,
    dot: 0,
    dT: 0,
    dieFreezeRollsRemaining: 0,
  };
}

function applyEnemyDieFreeze(e: SimEnemy, skips: number): void {
  if (skips <= 0 || e.hp <= 0) return;
  e.dieFreezeRollsRemaining += skips;
}

function getEnemyPlan(enemy: SimEnemy, suites: Record<string, EnemyAbilitySuite>): EnemyAbility {
  const z = enemyZoneFromRoll(d20());
  const suite = suites[enemy.type];
  const base = suite?.[z] ? { ...suite[z]! } : { ...EMPTY_ENEMY_AB };
  const scale = enemy.dmgScale || 1;
  if ((base.dmg || 0) > 0) base.dmg = Math.round(base.dmg * scale);
  if (base.dmgP2 && base.dmgP2 > 0) base.dmgP2 = Math.round(base.dmgP2 * scale);
  if (base.heal > 0) base.heal = Math.round(base.heal * scale);
  if (base.shield > 0) base.shield = Math.round(base.shield * scale);
  if ((base.shieldAlly || 0) > 0) base.shieldAlly = Math.round((base.shieldAlly || 0) * scale);
  if (base.dot > 0) base.dot = Math.round(base.dot * scale);
  if (enemy.p2 && base.dmgP2) base.dmg = base.dmgP2;
  return base;
}

function spawnEnemies(
  spawnList: { name: string }[],
  battleIndex: number,
  unitDefs: Record<string, Omit<EnemyDefinition, 'name'>>,
  battleScale: { hp: number; dmg: number }[],
  trackHpScale: number,
): SimEnemy[] {
  return spawnList.map(s => {
    const def = unitDefs[s.name];
    if (!def) throw new Error('Unknown unit: ' + s.name);
    return scaleEnemyDef({ ...def, name: s.name }, battleIndex, battleScale, trackHpScale);
  });
}

function pick3Heroes(all: HeroDefinition[]): HeroDefinition[] {
  const pool = [...all];
  const out: HeroDefinition[] = [];
  while (out.length < 3 && pool.length) {
    const i = Math.floor(Math.random() * pool.length);
    out.push(pool.splice(i, 1)[0]!);
  }
  return out;
}

function freshSquadFromDefs(defs: HeroDefinition[]): SimHero[] {
  return defs.map(d => ({
    id: d.id,
    name: d.name,
    maxHp: d.hp,
    hp: d.hp,
    shield: 0,
    shT: 0,
    shieldStacks: [],
    def: d,
    tier: 1,
    xp: 0,
    bRolls: [],
    activeAbilities: d.abilities.map(normalizeHeroAbility),
    dot: 0,
    dT: 0,
  }));
}

function livingHeroes(heroes: SimHero[]) {
  return heroes.filter(h => h.hp > 0);
}

function livingEnemies(enemies: SimEnemy[]) {
  return enemies.filter(e => e.hp > 0);
}

function lowestHpEnemyIndex(enemies: SimEnemy[]): number {
  let best = -1;
  let bestHp = Infinity;
  for (let i = 0; i < enemies.length; i++) {
    const e = enemies[i]!;
    if (e.hp <= 0) continue;
    if (e.hp < bestHp) {
      bestHp = e.hp;
      best = i;
    }
  }
  return best;
}

function damageEnemy(e: SimEnemy, dmg: number, ignSh: boolean): void {
  if (dmg <= 0) return;
  let d = dmg;
  if (!ignSh && coalesceShieldStacks(e).length > 0) {
    const { absorbed, ...sh } = absorbDamageThroughShield(e, d);
    Object.assign(e, sh);
    d = Math.max(0, d - absorbed);
  }
  e.hp -= d;
  if (e.pThr != null && !e.p2 && e.hp <= e.pThr) e.p2 = true;
}

function damageHero(h: SimHero, dmg: number): void {
  if (dmg <= 0 || h.hp <= 0) return;
  let d = dmg;
  if (coalesceShieldStacks(h).length > 0) {
    const { absorbed, ...sh } = absorbDamageThroughShield(h, d);
    Object.assign(h, sh);
    d = Math.max(0, d - absorbed);
  }
  h.hp -= d;
}

/** Player-phase start: tick DoT on enemies (matches game END TURN before hero resolves). */
function tickEnemyDots(enemies: SimEnemy[]): void {
  for (const e of enemies) {
    if (e.hp <= 0 || e.dot <= 0 || e.dT <= 0) continue;
    damageEnemy(e, e.dot, false);
    e.dT -= 1;
    if (e.dT <= 0) e.dot = 0;
  }
}

/** Enemy-phase start: tick DoT on heroes. */
function tickHeroDots(heroes: SimHero[]): void {
  for (const h of heroes) {
    if (h.hp <= 0 || h.dot <= 0 || h.dT <= 0) continue;
    damageHero(h, h.dot);
    h.dT -= 1;
    if (h.dT <= 0) h.dot = 0;
  }
}

function applyDotToEnemy(e: SimEnemy, amt: number, turns: number): void {
  if (amt <= 0 || turns <= 0 || e.hp <= 0) return;
  e.dot += amt;
  e.dT = Math.max(e.dT, turns);
}

function applyDotToHero(h: SimHero, amt: number, turns: number): void {
  if (amt <= 0 || turns <= 0 || h.hp <= 0) return;
  h.dot += amt;
  h.dT = Math.max(h.dT, turns);
}

function pickSmartHeroIndex(heroes: SimHero[]): number {
  const alive = heroes.map((h, i) => ({ h, i })).filter(x => x.h.hp > 0);
  if (!alive.length) return -1;
  alive.sort((a, b) => a.h.hp / a.h.maxHp - b.h.hp / b.h.maxHp);
  return alive[0]!.i;
}

function pickDumbHeroIndex(heroes: SimHero[]): number {
  const alive = heroes.map((_, i) => i).filter(i => heroes[i]!.hp > 0);
  if (!alive.length) return -1;
  return alive[Math.floor(Math.random() * alive.length)]!;
}

function resolveHeroAbility(
  h: SimHero,
  heroes: SimHero[],
  enemies: SimEnemy[],
  heroIdx: number,
  protocolBudget: { charges: number },
): void {
  let roll = d20();
  // Protocol: spend a charge to reroll if we landed in the worst zone (recharge ≤4)
  if (roll <= 4 && protocolBudget.charges > 0) {
    const reroll = d20();
    if (reroll > roll) roll = reroll;
    protocolBudget.charges--;
  }
  const ab = pickAbilityForRoll(h.activeAbilities, roll);
  if (!ab) return;
  if (h.tier === 1) h.bRolls.push(roll);

  const ignSh = !!ab.ignSh;

  const shDur = ab.shT || 2;
  if (ab.shieldAll && (ab.shield || 0) > 0) {
    for (const x of heroes) {
      if (x.hp > 0) Object.assign(x, addShieldToUnit(x, ab.shield!, shDur));
    }
  } else if (ab.shTgt && (ab.shield || 0) > 0) {
    const others = heroes.map((_, i) => i).filter(i => i !== heroIdx && heroes[i]!.hp > 0);
    const ti = others.length ? others[Math.floor(Math.random() * others.length)]! : heroIdx;
    const rx = heroes[ti]!;
    if (rx.hp > 0) Object.assign(rx, addShieldToUnit(rx, ab.shield!, shDur));
  } else if ((ab.shield || 0) > 0 && !ab.shieldAll) {
    Object.assign(h, addShieldToUnit(h, ab.shield!, shDur));
  }

  if (ab.healAll && (ab.heal || 0) > 0) {
    for (const x of heroes) {
      if (x.hp > 0) x.hp = Math.min(x.maxHp, x.hp + ab.heal!);
    }
  }

  if (ab.healLowest && (ab.heal || 0) > 0) {
    const alive = livingHeroes(heroes);
    if (alive.length) {
      const tgt = alive.reduce((a, b) => (a.hp / a.maxHp <= b.hp / b.maxHp ? a : b));
      tgt.hp = Math.min(tgt.maxHp, tgt.hp + ab.heal!);
    }
  }

  if (ab.healTgt && (ab.heal || 0) > 0) {
    const others = heroes.map((_, i) => i).filter(i => i !== heroIdx && heroes[i]!.hp > 0);
    const ti = others.length ? others[Math.floor(Math.random() * others.length)]! : heroIdx;
    if (heroes[ti]!.hp > 0) {
      heroes[ti]!.hp = Math.min(heroes[ti]!.maxHp, heroes[ti]!.hp + ab.heal!);
    }
  }

  const healOnlySelf =
    (ab.heal || 0) > 0 &&
    !ab.healAll &&
    !ab.healLowest &&
    !ab.healTgt &&
    !(ab.dmg || 0) &&
    !ab.shTgt;

  if (healOnlySelf && h.hp < h.maxHp) {
    h.hp = Math.min(h.maxHp, h.hp + ab.heal!);
  }

  const dmgVal = sampleHeroDamage(ab);
  const dotAmt = ab.dot || 0;
  const dotTurns = Math.max(ab.dT || 0, dotAmt > 0 ? DEFAULT_DOT_TURNS : 0);

  let singleDmgTargetIdx = -1;
  if ((ab.blastAll || ab.multiHit) && dmgVal > 0) {
    for (const e of enemies) {
      if (e.hp > 0) damageEnemy(e, dmgVal, ignSh);
    }
  } else if ((ab.dmg || 0) > 0 || dmgVal > 0) {
    const ei = lowestHpEnemyIndex(enemies);
    if (ei >= 0) {
      singleDmgTargetIdx = ei;
      damageEnemy(enemies[ei]!, dmgVal, ignSh);
    }
  }

  if (dotAmt > 0) {
    if (ab.blastAll) {
      for (const e of enemies) {
        if (e.hp > 0) applyDotToEnemy(e, dotAmt, dotTurns);
      }
    } else {
      const ei = lowestHpEnemyIndex(enemies);
      if (ei >= 0) applyDotToEnemy(enemies[ei]!, dotAmt, dotTurns);
    }
  }

  if (
    (ab.heal || 0) > 0 &&
    (ab.dmg || 0) > 0 &&
    !ab.healTgt &&
    !ab.healAll &&
    h.hp < h.maxHp
  ) {
    h.hp = Math.min(h.maxHp, h.hp + ab.heal!);
  }

  const freezeAll = ab.freezeAllEnemyDice || 0;
  if (freezeAll > 0) {
    for (const e of enemies) {
      if (e.hp > 0) applyEnemyDieFreeze(e, freezeAll);
    }
  }
  const freezeTgt = ab.freezeEnemyDice || 0;
  if (freezeTgt > 0 && singleDmgTargetIdx >= 0) {
    const te = enemies[singleDmgTargetIdx]!;
    if (te.hp > 0) applyEnemyDieFreeze(te, freezeTgt);
  }
}

function resolveEnemyTurn(
  enemy: SimEnemy,
  enemies: SimEnemy[],
  heroes: SimHero[],
  suites: Record<string, EnemyAbilitySuite>,
): void {
  const act = getEnemyPlan(enemy, suites);

  const eshT = act.shT || 2;
  if ((act.shield || 0) > 0) {
    Object.assign(enemy, addShieldToUnit(enemy, act.shield!, eshT));
  }

  if ((act.shieldAlly || 0) > 0) {
    const others = enemies.filter(x => x.hp > 0 && x !== enemy);
    if (others.length) {
      const tgt = others.reduce((a, b) => (a.hp < b.hp ? a : b));
      Object.assign(tgt, addShieldToUnit(tgt, act.shieldAlly!, eshT));
    }
  }

  if ((act.heal || 0) > 0) {
    const pool = enemies.filter(x => x.hp > 0);
    if (pool.length) {
      const tgt = pool.reduce((a, b) => (a.hp < b.hp ? a : b));
      tgt.hp = Math.min(tgt.maxHp, tgt.hp + act.heal!);
    }
  }

  const hi =
    (act.dmg || 0) > 0 || (act.dot || 0) > 0
      ? enemy.ai === 'smart'
        ? pickSmartHeroIndex(heroes)
        : pickDumbHeroIndex(heroes)
      : -1;

  if ((act.dmg || 0) > 0 && hi >= 0) {
    damageHero(heroes[hi]!, act.dmg);
  }

  if ((act.dot || 0) > 0 && hi >= 0) {
    const turns = Math.max(act.dT || 0, DEFAULT_DOT_TURNS);
    applyDotToHero(heroes[hi]!, act.dot, turns);
  }
}

function simulateBattle(
  heroes: SimHero[],
  enemies: SimEnemy[],
  suites: Record<string, EnemyAbilitySuite>,
  protocolBudget: { charges: number },
): boolean {
  const maxRounds = 400;
  for (let round = 0; round < maxRounds; round++) {
    if (!livingEnemies(enemies).length) return true;
    if (!livingHeroes(heroes).length) return false;

    tickEnemyDots(enemies);
    if (!livingEnemies(enemies).length) return true;
    if (!livingHeroes(heroes).length) return false;

    const order = [0, 1, 2].sort(() => Math.random() - 0.5);
    for (const hi of order) {
      const h = heroes[hi]!;
      if (h.hp > 0) resolveHeroAbility(h, heroes, enemies, hi, protocolBudget);
      if (!livingEnemies(enemies).length) return true;
    }

    if (!livingHeroes(heroes).length) return false;

    tickHeroDots(heroes);
    if (!livingHeroes(heroes).length) return false;

    for (const e of enemies) {
      if (e.hp > 0) resolveEnemyTurn(e, enemies, heroes, suites);
      if (!livingHeroes(heroes).length) return false;
    }

    for (const h of heroes) {
      if (h.hp <= 0) continue;
      if (coalesceShieldStacks(h).length > 0) Object.assign(h, tickUnitShield(h));
    }
    for (const e of enemies) {
      if (e.hp <= 0) continue;
      if (coalesceShieldStacks(e).length > 0) Object.assign(e, tickUnitShield(e));
    }
  }
  return false;
}

function interBattleReset(heroes: SimHero[]): void {
  for (const h of heroes) {
    if (h.hp > 0) h.hp = h.maxHp;
    else h.hp = Math.max(1, Math.round(h.maxHp * 0.8));
    h.shield = 0;
    h.shT = 0;
    h.shieldStacks = [];
    h.dot = 0;
    h.dT = 0;
  }
}

function trioKey(sortedIds: string[]): string {
  return sortedIds.join('+');
}

function survivorHpPct(heroes: SimHero[]): number {
  const alive = heroes.filter(h => h.hp > 0);
  if (!alive.length) return 0;
  return alive.reduce((sum, h) => sum + h.hp / h.maxHp, 0) / alive.length;
}

function battlesWonBeforeWipeWithSquad(
  battles: { enemies: { name: string }[] }[],
  input: BattleProgressSimInput,
  modeId: BattleModeId,
): { wins: number; squadIds: string[]; hpPctPerWin: number[] } {
  const defs = pick3Heroes(input.heroes);
  if (defs.length === 0) return { wins: 0, squadIds: [], hpPctPerWin: [] };
  const squadIds = defs.map(d => d.id);
  const heroes = freshSquadFromDefs(defs);
  let wins = 0;
  const hpPctPerWin: number[] = [];
  const trackHp = input.trackHpScaleByMode[modeId] ?? 1;
  // Protocol budget is shared across the whole track
  const protocolBudget = { charges: Math.max(0, input.protocolRerolls | 0) };

  for (let b = 0; b < battles.length; b++) {
    const enemies = spawnEnemies(battles[b]!.enemies, b, input.unitDefs, input.battleScale, trackHp);
    const win = simulateBattle(heroes, enemies, input.suites, protocolBudget);
    if (!win) return { wins, squadIds, hpPctPerWin };
    wins += 1;
    hpPctPerWin.push(survivorHpPct(heroes));
    interBattleReset(heroes);
    awardXpAfterWin(heroes);
    tryEvolveSquad(heroes, b);
  }
  return { wins, squadIds, hpPctPerWin };
}

export function runBattleProgressSim(input: BattleProgressSimInput, iterations: number): BattleProgressSimResult {
  const n = Math.max(50, Math.min(50000, Math.floor(iterations) || 3000));
  const tracks: BattleProgressSimResult['tracks'] = [];

  const heroIds = [...new Set(input.heroes.map(h => h.id))].sort();
  const heroRunHits: Record<string, number> = Object.fromEntries(heroIds.map(id => [id, 0]));
  const heroFullHits: Record<string, number> = Object.fromEntries(heroIds.map(id => [id, 0]));
  const trioAgg = new Map<string, { ids: [string, string, string]; runs: number; fullClears: number; winSum: number }>();
  let totalRuns = 0;
  let fullClearsAllModes = 0;

  for (const modeId of input.modeOrder) {
    const battles = input.battlesByMode[modeId];
    if (!battles?.length) continue;

    const nBattles = battles.length;
    // counts[k] = runs that reached (attempted) battle k+1 (0-based)
    const reachCounts = new Array(REACH_BATTLE_COUNT).fill(0);
    // winCounts[k] = runs that WON battle k+1 (0-based)
    const winCounts = new Array(REACH_BATTLE_COUNT).fill(0);
    // hpPctSum[k] / hpPctN[k] = avg survivor HP% after winning battle k+1
    const hpPctSum = new Array(nBattles).fill(0);
    const hpPctN = new Array(nBattles).fill(0);
    let modeFullClears = 0;

    for (let i = 0; i < n; i++) {
      const { wins, squadIds, hpPctPerWin } = battlesWonBeforeWipeWithSquad(battles, input, modeId);
      totalRuns += 1;
      if (squadIds.length === 3) {
        const sorted = [...squadIds].sort() as [string, string, string];
        const tk = trioKey(sorted);
        let row = trioAgg.get(tk);
        if (!row) {
          row = { ids: sorted, runs: 0, fullClears: 0, winSum: 0 };
          trioAgg.set(tk, row);
        }
        row.runs += 1;
        row.winSum += wins;
        if (wins === nBattles && nBattles > 0) {
          row.fullClears += 1;
        }
      }
      for (const id of squadIds) {
        heroRunHits[id] = (heroRunHits[id] || 0) + 1;
      }
      if (wins === nBattles && nBattles > 0) {
        modeFullClears += 1;
        fullClearsAllModes += 1;
        for (const id of squadIds) {
          heroFullHits[id] = (heroFullHits[id] || 0) + 1;
        }
      }
      // Reach counts: a squad "reaches" battle k if it won k-1 prior fights
      for (let k = 0; k < REACH_BATTLE_COUNT; k++) {
        if (wins >= k) reachCounts[k] += 1;       // reached battle k+1
        if (wins >= k + 1) winCounts[k] += 1;     // won battle k+1
      }
      // HP% per won battle
      for (let b = 0; b < hpPctPerWin.length && b < nBattles; b++) {
        hpPctSum[b] += hpPctPerWin[b]!;
        hpPctN[b] += 1;
      }
    }

    const reachBattlePct = reachCounts.map(c => (100 * c) / n);
    const conditionalWinPct = reachCounts.map((reached, k) =>
      reached > 0 ? (100 * winCounts[k]!) / reached : 0,
    );
    const avgSurvivorHpPct: (number | null)[] = hpPctN.map((cnt, b) =>
      cnt > 0 ? (100 * hpPctSum[b]!) / cnt : null,
    );

    tracks.push({
      modeId,
      label: input.modeLabels[modeId] ?? modeId,
      battlesInTrack: nBattles,
      reachBattlePct,
      conditionalWinPct,
      avgSurvivorHpPct,
      fullClearPct: (100 * modeFullClears) / n,
    });
  }

  const fair = EXPECTED_HERO_RUN_INCLUSION_PCT;
  const byHero: BattleProgressSimHeroRep[] = heroIds.map(heroId => {
    const runsHit = heroRunHits[heroId] ?? 0;
    const pctOfRuns = totalRuns > 0 ? (100 * runsHit) / totalRuns : 0;
    const deltaVsFairRunsPct = pctOfRuns - fair;

    let pctOfFullClearRuns: number | null = null;
    let deltaVsFairFullClearPct: number | null = null;
    let representationIndexFullClear: number | null = null;

    if (fullClearsAllModes > 0) {
      const fcHit = heroFullHits[heroId] ?? 0;
      pctOfFullClearRuns = (100 * fcHit) / fullClearsAllModes;
      deltaVsFairFullClearPct = pctOfFullClearRuns - fair;
      const expectedFc = (fullClearsAllModes * 3) / 8;
      representationIndexFullClear = expectedFc > 0 ? fcHit / expectedFc : null;
    }

    return {
      heroId,
      pctOfRuns,
      deltaVsFairRunsPct,
      pctOfFullClearRuns,
      deltaVsFairFullClearPct,
      representationIndexFullClear,
    };
  });

  byHero.sort((a, b) => {
    const ia = a.representationIndexFullClear;
    const ib = b.representationIndexFullClear;
    if (ia != null && ib != null && Math.abs(ib - ia) > 1e-6) return ib - ia;
    return b.deltaVsFairRunsPct - a.deltaVsFairRunsPct;
  });

  const minRunsForRanked = Math.max(8, Math.min(40, Math.floor(totalRuns / 250)));
  const toTrioStats = (row: { ids: [string, string, string]; runs: number; fullClears: number; winSum: number }): BattleProgressSimTrioStats => ({
    heroIds: row.ids,
    runs: row.runs,
    fullClears: row.fullClears,
    fullClearPct: row.runs > 0 ? (100 * row.fullClears) / row.runs : 0,
    meanWins: row.runs > 0 ? row.winSum / row.runs : 0,
  });

  const allTrios = [...trioAgg.values()].map(toTrioStats).sort((a, b) => b.meanWins - a.meanWins || b.fullClearPct - a.fullClearPct);

  const rankedPool = allTrios.filter(t => t.runs >= minRunsForRanked);
  const topByMeanWins = [...rankedPool].sort((a, b) => b.meanWins - a.meanWins || b.fullClearPct - a.fullClearPct).slice(0, 15);

  const withAnyFc = rankedPool.filter(t => t.fullClears > 0);
  const topByFullClearPct = [...withAnyFc]
    .sort((a, b) => b.fullClearPct - a.fullClearPct || b.fullClears - a.fullClears || b.meanWins - a.meanWins)
    .slice(0, 15);

  return {
    iterations: n,
    reachBattleCount: REACH_BATTLE_COUNT,
    protocolRerolls: Math.max(0, input.protocolRerolls | 0),
    tracks,
    heroRepresentation: {
      totalRuns,
      fullClearsAllModes,
      byHero,
    },
    trioStats: {
      minRunsForRanked,
      topByMeanWins,
      topByFullClearPct,
      allTrios,
    },
  };
}

export function formatBattleProgressSimResult(r: BattleProgressSimResult): string {
  const protoNote = r.protocolRerolls > 0
    ? `Protocol: ${r.protocolRerolls} reroll(s)/track (spend on ≤4 roll, keep higher).`
    : 'Protocol: none modeled.';
  const lines: string[] = [
    `Battle progress sim — ${r.iterations} runs/track × ${r.tracks.length} operations, random 3-hero squads`,
    `Reach% = cumulative (attempted that fight). Cond% = win rate given you reached that fight. HP% = avg survivor HP after a win.`,
    `Evolution included. DoT + shield modeled. ${protoNote} No items or summons.`,
    '',
  ];
  for (const t of r.tracks) {
    lines.push(`── ${t.label} (${t.modeId}) — ${t.battlesInTrack} fights ──`);
    lines.push(`  ${'Full clear'.padEnd(22)} ${'Reach%'.padStart(7)} ${'Cond%'.padStart(7)} ${'HP%'.padStart(6)}`);
    lines.push(`  ${'(all fights)'.padEnd(22)} ${t.fullClearPct.toFixed(1).padStart(7)}%`);
    const nFights = Math.min(t.battlesInTrack, r.reachBattleCount);
    for (let k = 0; k < nFights; k++) {
      const label = `Fight ${k + 1}`;
      const reach = (t.reachBattlePct[k] ?? 0).toFixed(1).padStart(7);
      const cond  = (t.conditionalWinPct[k] ?? 0).toFixed(1).padStart(7);
      const hp    = t.avgSurvivorHpPct[k] != null
        ? (t.avgSurvivorHpPct[k]! * 100 / 100).toFixed(1).padStart(6)
        : '  n/a';
      lines.push(`  ${label.padEnd(22)} ${reach}% ${cond}% ${hp}%`);
    }
    lines.push('');
  }

  const hr = r.heroRepresentation;
  const fair = EXPECTED_HERO_RUN_INCLUSION_PCT;
  lines.push('── Hero representation vs fair random squad (3 of 8) ──');
  lines.push(
    '  Not “who carries”: each hero is on ~37.5% of squads. FC over-rep is correlation (who appeared on clearing trios), not causal DPS under this sim.',
  );
  lines.push(`  Fair inclusion per hero ≈ ${fair.toFixed(1)}% of runs (all ops aggregated).`);
  lines.push(`  Total simulated runs: ${hr.totalRuns} · Full clears (any op): ${hr.fullClearsAllModes}`);
  if (hr.fullClearsAllModes === 0) {
    lines.push(
      '  No full clears this batch — raise iterations or ease data. Run-% deltas below are ~MC noise (uniform pick).',
    );
  }
  lines.push('');
  lines.push(
    '  Over-rep when clearing: rep index = actual FC appearances ÷ expected (FC×3/8); 1.0 fair, >1 over-represented.',
  );
  lines.push('');
  for (const h of hr.byHero) {
    const runPart = `${h.pctOfRuns.toFixed(1)}% runs (${h.deltaVsFairRunsPct >= 0 ? '+' : ''}${h.deltaVsFairRunsPct.toFixed(1)}% vs fair)`;
    let fcPart = 'full clear: n/a';
    if (hr.fullClearsAllModes > 0 && h.representationIndexFullClear != null) {
      fcPart = `${h.pctOfFullClearRuns!.toFixed(1)}% of FC runs (${h.deltaVsFairFullClearPct! >= 0 ? '+' : ''}${h.deltaVsFairFullClearPct!.toFixed(1)}%) · idx ${h.representationIndexFullClear.toFixed(2)}`;
    }
    lines.push(`  ${h.heroId.padEnd(12)} ${runPart} · ${fcPart}`);
  }
  lines.push('');

  const ts = r.trioStats;
  lines.push('── Trios (exact 3-hero sets) — empirical under this sim ──');
  lines.push(
    `  Each line = one unordered squad. Counts pool all operations (each run is one op × one random trio). Min runs for “top” lists: ${ts.minRunsForRanked}.`,
  );
  lines.push('  Mean wins = avg fights cleared on the rolled track before wipe; FC% = share of runs that full-cleared that track.');
  lines.push('');
  lines.push(`  Top by mean wins (depth) — min ${ts.minRunsForRanked} runs:`);
  if (ts.topByMeanWins.length === 0) {
    lines.push('    (no trio met sample threshold — raise iterations)');
  } else {
    for (const t of ts.topByMeanWins) {
      const ids = t.heroIds.join(' + ');
      lines.push(
        `    ${ids.padEnd(38)} runs ${String(t.runs).padStart(5)} · mean wins ${t.meanWins.toFixed(2)} · FC ${t.fullClearPct.toFixed(2)}% (${t.fullClears})`,
      );
    }
  }
  lines.push('');
  lines.push(`  Top by full-clear % (trios with ≥1 full clear only; min ${ts.minRunsForRanked} runs):`);
  if (ts.topByFullClearPct.length === 0) {
    lines.push('    (none — raise iterations or no FCs in sample)');
  } else {
    for (const t of ts.topByFullClearPct) {
      const ids = t.heroIds.join(' + ');
      lines.push(
        `    ${ids.padEnd(38)} runs ${String(t.runs).padStart(5)} · FC ${t.fullClearPct.toFixed(2)}% (${t.fullClears}) · mean wins ${t.meanWins.toFixed(2)}`,
      );
    }
  }
  lines.push('');
  return lines.join('\n');
}
